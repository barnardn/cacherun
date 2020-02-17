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

public final class OutputCachingExecutor {

    enum Utility {}

    private let cacheTimeInSeconds: Int
    private let command: String
    private let commandArgs: [String]

    public init(cacheTime: Int, userCommand: [String]) {
        self.cacheTimeInSeconds = cacheTime
        self.command = userCommand[0]
        commandArgs = userCommand.count > 1 ? Array(userCommand[1...]) : []
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

            switch shouldUpdateCache(pidFile: pidFile, cacheFile: cacheFile) {
            case .success(let shouldRun):
                if !shouldRun {
                    showCommandOutput(try? Data(contentsOf: cacheFile.asURL))
                    return .success(true)
                }
            case .failure(let error):
                return .failure(error)
            }

            let pathEnv = ProcessInfo.processInfo.environment["PATH"]
            guard let commandURL = Utility.findCommand(command: command, pathEnvironmentValue: pathEnv) else {
                return .failure(.badCommand(reason: "\(command) is not a valid path or command name"))
            }

            try execute(commandPath: commandURL, pidFile: pidFile, cacheFile: cacheFile)
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
        setupErrorOutputNotification(on: task, errorTextStream: stderrStream)
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
            // copy the data from the pipe, since we need it in two places.
            let commandData = Data(referencing: outputPipe.fileHandleForReading.availableData as NSData)
            self?.showCommandOutput(commandData)
            try? commandData.write(to: cacheFile.asURL)
        }
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }

    private func setupErrorOutputNotification(on task: Foundation.Process, errorTextStream: TextOutputStream) {
        let errorPipe = Pipe()
        task.standardError = errorPipe
        NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: errorPipe.fileHandleForReading, queue: nil) { [weak self] notification in
            self?.showCommandOutput(errorPipe.fileHandleForReading.availableData, on: stderrStream)
        }
        errorPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }

    /// converts the output of the command to a string and write it to stdout
    /// - Parameter output: command output
    ///
    private func showCommandOutput(_ output: Data?, on stream: OutputByteStream = stdoutStream) {
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
    private func shouldUpdateCache(pidFile: AbsolutePath, cacheFile: AbsolutePath) -> Result<Bool, CacheExecutorError> {
            // pid of previous run exists, command still running
        guard !localFileSystem.isFile(pidFile) else { return .success(false) }

            // no output, run command for first time
        guard localFileSystem.isFile(cacheFile) else { return .success(true) }

        return .success(
            Utility.isStaleFile(at: cacheFile, maxAgeInSeconds: TimeInterval(cacheTimeInSeconds))
        )
    }

    /// check for the existence of the run folder for the command. this is where we keep the cached command data and
    /// any lock files. if we can't create a folder in the caches directory, we'll just use /tmp
    /// - Returns: the url to the run dir location
    private func checkRunDirAndCreate() -> AbsolutePath {
        guard
            let appSupportURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else {
            return AbsolutePath("/tmp")
        }
        let appSupportPath = AbsolutePath(appSupportURL.path)
        let runDir = appSupportPath.appending(component: "cacherun")
        if !localFileSystem.isDirectory(runDir) {
            do { try localFileSystem.createDirectory(runDir) }
            catch { return AbsolutePath("/tmp") }
        }
        return runDir
    }

}
