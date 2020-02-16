//
//  CacheExecutor.swift
//  
//
//  Created by Norman Barnard on 2/15/20.
//

import Foundation
import CryptoKit


public enum CacheExecutorError: Error {
    case hashFailure(String)
    case relativeCommandPathNotAllowed
    case commandNotFound
}

final class CacheExecutor {
    private let cacheTimeInSeconds: Int
    private let command: String
    private let commandArgs: [String]
    private let taskQueue = DispatchQueue.global(qos: .background)


    public init(cacheTime: Int, userCommand: [String]) {
        self.cacheTimeInSeconds = cacheTime
        self.command = userCommand[0]
        if userCommand.count > 1 {
            commandArgs = Array(userCommand[1...])
        } else {
            commandArgs = []
        }
    }

    public func runCachedCommand() throws {

        guard !command.starts(with: ".") else { throw CacheExecutorError.relativeCommandPathNotAllowed }

        let rundir = checkRunDirAndCreate()
        print("Rundir is: \(rundir.path)")
        let commandHash = try CacheExecutor.sha256Hash(for: ([command] + commandArgs).joined(separator: " "))
        let pidFileURL = rundir.appendingPathComponent("\(commandHash).pid")
        let cachedOutputURL = rundir.appendingPathComponent("\(commandHash).data")
        guard try shouldUpdateCache(pidFileURL: pidFileURL, cacheFileURL: cachedOutputURL) else { return  }

        let commandURL: URL
        if command.contains("/") {
            commandURL = URL(fileURLWithPath: command)
        } else {
            guard
                let pathSpec = ProcessInfo.processInfo.environment["PATH"],
                let url = CacheExecutor.findCommandURL(command: command, in: pathSpec.components(separatedBy: ":"))
            else {
                throw CacheExecutorError.commandNotFound
            }
            commandURL = url
        }
        try execute(commandPath: commandURL, pidFileURL: pidFileURL, cachedOutputURL: cachedOutputURL)
    }

    private func execute(commandPath: URL, pidFileURL: URL, cachedOutputURL: URL) throws {

        let task = Process()
        task.executableURL = commandPath
        task.arguments = commandArgs
        task.environment = ProcessInfo.processInfo.environment
        task.terminationHandler = { task in
            do {
                try? FileManager.default.removeItem(at: pidFileURL)
            }
            print("task done!")
        }

        taskQueue.async {
            do {
                let outPipe = Pipe()
                task.standardOutput = outPipe

                NotificationCenter.default.addObserver(
                    forName: Notification.Name.NSFileHandleDataAvailable,
                    object: outPipe.fileHandleForReading,
                    queue: nil
                ) { notification in
//                    let output = outPipe.fileHandleForReading.availableData
//                    let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
//                    print(outputString)
                    try? outPipe.fileHandleForReading.availableData.write(to: cachedOutputURL)
                }
                outPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()

                try task.run()
                try "\(task.processIdentifier)".write(to: pidFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("error in task run \(error.localizedDescription)")
            }
            task.waitUntilExit()
        }

    }


    /// checks if the cache time has expired on the existing cache file.
    /// - Parameter pidFileURL: url to the file of the previous run's process id
    /// - Parameter cacheFileURL: url to the previous run's output
    /// - Returns: true of time expired or cacheFile doesn't exist
    ///
    private func shouldUpdateCache(pidFileURL: URL, cacheFileURL: URL) throws -> Bool {
            // pid of previous run exists, command still running
        guard !FileManager.default.fileExists(atPath: pidFileURL.path) else { return false }

            // no output, run command for first time
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return true }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: cacheFileURL.path)
        guard let modificationDate = fileAttributes[FileAttributeKey.modificationDate] as? Date else { return false }

        // last modification date more than cacheTimeInSeconds old?
        return Date().timeIntervalSince(modificationDate) > TimeInterval(cacheTimeInSeconds)
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

    private static func createDirectory(at url: URL) -> URL {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [:])
            return url
        } catch {
            return URL(fileURLWithPath: "/tmp")
        }
    }

    private static func sha256Hash(for string: String) throws -> String {
        return "flurm"
//        guard let stringData = string.data(using: .utf8) else { throw CacheExecutorError.hashFailure(string) }
//        return SHA256.hash(data: stringData).description
    }

    private static func findCommandURL(command: String, in pathDirs: [String]) -> URL? {
        return pathDirs.map { path -> String in
            return (path.components(separatedBy: "/") + [command]).joined(separator: "/")
        }.compactMap { path -> URL? in
            return URL(fileURLWithPath: path)
        }.first { candidateURL -> Bool in
            FileManager.default.fileExists(atPath: candidateURL.path)
        }
    }


}
