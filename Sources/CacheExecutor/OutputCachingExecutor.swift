//
//  OutputCachingExecutor.swift
//  
//
//  Created by Norman Barnard on 2/15/20.
//

import Foundation
import Basic
import CryptoKit

public enum CacheExecutorError: Error {
    case hashFailure(String)
    case badCommand(reason: String)
    case systemError(Error)
}

private enum CacheFileStatus {
    case stale
    case fresh
    case awaitingFirstResult
}

public final class OutputCachingExecutor {

    enum Utility {}
    public enum CacheManagement {}

    private let cacheTimeInSeconds: Int
    private let command: String
    private let commandArgs: [String]

    private let outputStream: OutputByteStream
    private let errorStream: OutputByteStream

    public init(cacheTime: Int, userCommand: [String], outputStream: OutputByteStream = stdoutStream, errorStream: OutputByteStream = stderrStream) {
        self.cacheTimeInSeconds = cacheTime
        self.command = userCommand[0]
        commandArgs = userCommand.count > 1 ? Array(userCommand[1...]) : []
        self.outputStream = outputStream
        self.errorStream = errorStream
    }

    /// run the command or return the cached results if the cached output from the last run isn't stale.
    ///
    public func runCachedCommand() -> Result<Bool, CacheExecutorError> {

        // punt on relative paths for now..  maybe use currentDirectory on task path?
        guard !command.starts(with: ".") else {
            return .failure(.badCommand(reason: "Relative path to command not allowed. Use full path or command name only"))
        }

        let rundir = checkRunDirAndCreate()
        do {

            let commandHash = try Utility.sha256Hash(for: ([command] + commandArgs).joined(separator: " "))
            let pidFile = rundir.appending(component: "\(commandHash).pid")
            let cacheFile = rundir.appending(component: "\(commandHash).data")

            switch shouldUpdateCache(pidFile: pidFile, cacheFile: cacheFile, commandHash: commandHash) {
            case .awaitingFirstResult:
                return .success(false)
            case .fresh:
                showCommandOutput(try? Data(contentsOf: cacheFile.asURL), on: outputStream)
                return .success(true)
            case .stale:
                break;
            }

            let pathEnv = ProcessInfo.processInfo.environment["PATH"]
            guard let commandURL = Utility.findCommand(command: command, pathEnvironmentValue: pathEnv) else {
                return .failure(.badCommand(reason: "\(command) is not a valid path or command name"))
            }

            try execute(commandPath: commandURL, pidFile: pidFile, cacheFile: cacheFile)

            // write out the commmand as executed for reporting
            let commandFile = rundir.appending(component: "\(commandHash).cmd")
            try "\(command) \(commandArgs.joined(separator: " "))".write(to: commandFile.asURL, atomically: true, encoding: .utf8)

            return .success(true)

        } catch CacheExecutorError.hashFailure(let message) {
            return .failure(.hashFailure(message))
        } catch {
            return .failure(.systemError(error))
        }
    }

    private func execute(commandPath: AbsolutePath, pidFile: AbsolutePath, cacheFile: AbsolutePath) throws {

        defer { try? localFileSystem.removeFileTree(pidFile) }

        let task = Process()
        task.executableURL = commandPath.asURL
        task.arguments = commandArgs

        setupOutputNotification(on: task, cacheFile: cacheFile)
        setupErrorOutputNotification(on: task, errorStream: errorStream)
        try task.run()
        try "\(task.processIdentifier)".write(to: pidFile.asURL, atomically: true, encoding: .utf8)
        task.waitUntilExit()
    }


    /// sets up a notification that reads any available output captured by a pipe that's attached to the
    /// command stdout. the output is dumped to the cache file and then written to the parent's stdout
    /// - Parameters:
    ///   - task: the task to execute
    ///   - cachedOutputURL: file URL to the cached output file.
    ///
    private func setupOutputNotification(on task: Foundation.Process, cacheFile: AbsolutePath) {
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            // copy the data from the pipe, since we need it in two places.
            let commandData = Data(referencing: outputPipe.fileHandleForReading.availableData as NSData)
            self.showCommandOutput(commandData, on: self.outputStream)
            try? commandData.write(to: cacheFile.asURL)
        }
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }

    private func setupErrorOutputNotification(on task: Foundation.Process, errorStream: OutputByteStream) {
        let errorPipe = Pipe()
        task.standardError = errorPipe
        NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: errorPipe.fileHandleForReading, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            self.showCommandOutput(errorPipe.fileHandleForReading.availableData, on: errorStream)
        }
        errorPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }

    /// converts the output of the command to a string and write it to stdout
    /// - Parameter output: command output
    ///
    private func showCommandOutput(_ output: Data?, on stream: OutputByteStream) {
        guard let output = output else { return }
        if let textData = String(data: output, encoding: .utf8), textData.count > 0 {
            textData.write(to: stream)
            stream.flush()
        }
    }

    /// checks if the cache time has expired on the existing cache file.
    /// - Parameter pidFile: url to the file of the previous run's process id
    /// - Parameter cacheFile: url to the previous run's output
    /// - Returns: true of time expired or cacheFile doesn't exist
    ///
    private func shouldUpdateCache(pidFile: AbsolutePath, cacheFile: AbsolutePath, commandHash: String) -> CacheFileStatus {

        let commandStillRunning: Bool
        if localFileSystem.isFile(pidFile) {
            commandStillRunning = { () -> Bool in
                guard
                    let lastProcessIdentifer = try? String(contentsOf: pidFile.asURL, encoding: .utf8),
                    let pid = Int(lastProcessIdentifer)
                else  { return false }
                return (try? Utility.findProcess(withPid: pid, commandHash: commandHash)) ?? false
            }()
            // we have pid file, but can't find the command that made it, kill the pid file
            if !commandStillRunning {
                try? localFileSystem.removeFileTree(pidFile)
            }
        } else {
            commandStillRunning = false
        }

        if commandStillRunning && !localFileSystem.isFile(cacheFile) {
            return .awaitingFirstResult
        }

        defer {
            if commandStillRunning {
                try? localFileSystem.removeFileTree(pidFile)
            }
        }
        return Utility.isStaleFile(at: cacheFile, maxAgeInSeconds: TimeInterval(cacheTimeInSeconds)) ? .stale : .fresh
    }

    /// check for the existence of the run folder for the command. this is where we keep the cached command data and
    /// any lock files. if we can't create a folder in the caches directory, we'll just use /tmp
    /// - Returns: the url to the run dir location
    private func checkRunDirAndCreate() -> AbsolutePath {
        let runDir = Utility.locateRunDirectory()
        if !localFileSystem.isDirectory(runDir) {
            do { try localFileSystem.createDirectory(runDir) }
            catch { return AbsolutePath("/tmp") }
        }
        return runDir
    }

}
