//
//  CacheExecutor.swift
//  
//
//  Created by Norman Barnard on 2/15/20.
//

import Foundation
import var Basic.stdoutStream   // explicit to not collide with Process
import var Basic.stderrStream
import protocol Basic.OutputByteStream
import CryptoKit

public enum CacheExecutorError: Error {
    case hashFailure(String)
    case badCommand(reason: String)
    case systemError(Error)
}

final class CacheExecutor {
    private let cacheTimeInSeconds: Int
    private let command: String
    private let commandArgs: [String]

    public init(cacheTime: Int, userCommand: [String]) {
        self.cacheTimeInSeconds = cacheTime
        self.command = userCommand[0]
        if userCommand.count > 1 {
            commandArgs = Array(userCommand[1...])
        } else {
            commandArgs = []
        }
    }

    /// run the command or return the cached results if the cached output from the last run isn't stale.
    ///
    public func runCachedCommand() -> Result<Bool, CacheExecutorError> {

        guard !command.starts(with: ".") else {
            return .failure(.badCommand(reason: "Relative path to command not allowed. Use full path or command name only"))
        }

        let rundir = checkRunDirAndCreate()
        do {

            let commandHash = try CacheExecutor.sha256Hash(for: ([command] + commandArgs).joined(separator: " "))
            let pidFileURL = rundir.appendingPathComponent("\(commandHash).pid")
            let cachedOutputURL = rundir.appendingPathComponent("\(commandHash).data")

            switch shouldUpdateCache(pidFileURL: pidFileURL, cacheFileURL: cachedOutputURL) {
            case .success(let shouldRun):
                if !shouldRun {
                    showCommandOutput(try? Data(contentsOf: cachedOutputURL))
                    return .success(true)
                }
            case .failure(let error):
                return .failure(error)
            }

            guard let commandURL = CacheExecutor.findCommand(command: command) else {
                return .failure(.badCommand(reason: "\(command) is not a valid path or command name"))
            }

            try execute(commandPath: commandURL, pidFileURL: pidFileURL, cachedOutputURL: cachedOutputURL)
            return .success(true)

        } catch CacheExecutorError.hashFailure(let message) {
            return .failure(.hashFailure(message))
        } catch {
            return .failure(.systemError(error))
        }
    }

    private func execute(commandPath: URL, pidFileURL: URL, cachedOutputURL: URL) throws {

        defer { try? FileManager.default.removeItem(at: pidFileURL) }

        let task = Process()
        task.executableURL = commandPath
        task.arguments = commandArgs
        task.environment = ProcessInfo.processInfo.environment

        setupOutputNotification(on: task, cachedOutputURL: cachedOutputURL)
        setupErrorOutputNotification(on: task, errorTextStream: stderrStream)
        try task.run()
        try "\(task.processIdentifier)".write(to: pidFileURL, atomically: true, encoding: .utf8)
        task.waitUntilExit()
    }


    /// sets up a notification that reads any available output captured by a pipe that's attached to the
    /// command stdout. the output is dumped to the cache file and then written to the parent's stdout
    /// - Parameters:
    ///   - task: the task to execute
    ///   - cachedOutputURL: file URL to the cached output file.
    ///
    private func setupOutputNotification(on task: Process, cachedOutputURL: URL) {
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading, queue: nil) { [weak self] notification in
            // copy the data from the pipe, since we need it in two places.
            let commandData = Data(referencing: outputPipe.fileHandleForReading.availableData as NSData)
            self?.showCommandOutput(commandData)
            try? commandData.write(to: cachedOutputURL)
        }
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }

    private func setupErrorOutputNotification(on task: Process, errorTextStream: TextOutputStream) {
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
    /// - Parameter pidFileURL: url to the file of the previous run's process id
    /// - Parameter cacheFileURL: url to the previous run's output
    /// - Returns: true of time expired or cacheFile doesn't exist
    ///
    private func shouldUpdateCache(pidFileURL: URL, cacheFileURL: URL) -> Result<Bool, CacheExecutorError> {
            // pid of previous run exists, command still running
        guard !FileManager.default.fileExists(atPath: pidFileURL.path) else { return .success(false) }

            // no output, run command for first time
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return .success(true) }

        do {
            return .success(
                try CacheExecutor.isStaleFile(at: cacheFileURL, maxAgeInSeconds: TimeInterval(cacheTimeInSeconds))
            )
        } catch {
            return .failure(.systemError(error))
        }
    }

    /// check for the existence of the run folder for the command. this is where we keep the cached command data and
    /// any lock files. if we can't create a folder in the caches directory, we'll just use /tmp
    /// - Returns: the url to the run dir location
    private func checkRunDirAndCreate() -> URL {
        guard
            let appSupportDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else {
            return URL(fileURLWithPath: "/tmp")
        }
        let runDir = appSupportDir.appendingPathComponent("cacherun", isDirectory: true)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: runDir.path, isDirectory: &isDir) {
            return isDir.boolValue ? runDir : CacheExecutor.createDirectory(at: runDir)
        } else {
            return CacheExecutor.createDirectory(at: runDir)
        }
    }

    // MARK: static methods

    private static func isStaleFile(at url: URL, maxAgeInSeconds maxAge: TimeInterval) throws -> Bool {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let modificationDate = fileAttributes[FileAttributeKey.modificationDate] as? Date else { return true }
        return Date().timeIntervalSince(modificationDate) > maxAge
    }


    private static func createDirectory(at url: URL) -> URL {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [:])
            return url
        } catch {
            return URL(fileURLWithPath: "/tmp")
        }
    }

    private static func sha256Hash(for string: String) throws -> String {
        guard let stringData = string.data(using: .utf8) else { throw CacheExecutorError.hashFailure(string) }
        let hash = SHA256.hash(data: stringData)
        let hashString = hash.makeIterator().map { value -> String in
            String(format: "%02x", value)
        }
        return hashString.joined()
    }

    private static func findCommand(command: String) -> URL? {

        // command contains a separator, assume it's a full path
        guard !command.contains("/") else { return URL(fileURLWithPath: command) }

        let pathDirs = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") ?? []

        return pathDirs.map { path -> String in
            return (path.components(separatedBy: "/") + [command]).joined(separator: "/")
        }.compactMap { path -> URL? in
            return URL(fileURLWithPath: path)
        }.first { candidateURL -> Bool in
            FileManager.default.fileExists(atPath: candidateURL.path)
        }
    }


}
