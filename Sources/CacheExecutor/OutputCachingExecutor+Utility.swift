//
//  File.swift
//  
//
//  Created by Norman Barnard on 2/17/20.
//

import Foundation
import CryptoKit
import SystemPackage

extension OutputCachingExecutor.Utility {

    /// Locate `command` in the user's path verifying that it's executable. If there are multiple
    /// executable commands found, return the first one.
    /// - Parameter command: file name of the sought after command
    ///
    static func findCommand(command: String, pathEnvironmentValue: String?) -> FilePath? {
        guard let pathEnvironmentVar = pathEnvironmentValue else { return nil }

        // command contains a separator, assume it's a full path
        let commandURL = URL(fileURLWithPath: command)
        let commandPath = FilePath(commandURL.path())
        guard !commandPath.isExecutableFile() else {
            return commandPath
        }

        let pathDirs = pathEnvironmentVar.components(separatedBy: ":")

        return pathDirs.compactMap { path -> FilePath? in
            let commandURL = URL(fileURLWithPath: command, relativeTo: URL(fileURLWithPath: path, isDirectory: true))
            return FilePath(commandURL.path())
        }.filter { candidatePath -> Bool in
            candidatePath.isExecutableFile()
        }.first
    }

    static func sha256Hash(for string: String) throws -> String {
        guard let stringData = string.data(using: .utf8) else { throw CacheExecutorError.hashFailure(string) }
        return SHA256.hash(data: stringData).asString
    }

    static func isStaleFile(at path: FilePath, maxAgeInSeconds maxAge: TimeInterval) -> Bool {
        guard let modTime = path.modificationDate() else { return true }

        return Date().timeIntervalSince1970 - modTime.timeIntervalSince1970 > maxAge
    }

    static func locateRunDirectory(fileManager: FileManager = .default) -> FilePath {
        guard
            let appSupportURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else {
            return FilePath("/tmp")
        }
        let appSupportPath = FilePath(appSupportURL.path())
        return appSupportPath.appending("cacherun")
    }

    static func findProcess(withPid pid: Int, commandHash: String) throws -> Bool {
        let cmd = URL(filePath: "/bin/ps")
        let args = ["-o command=", "-p \(pid)"]
        let ps = ProcessPipe.popen(cmd: cmd, args: args)
        guard let matchingCommand = try ps.readAll() else {
            return false
        }
        let matchingCommandHash = try sha256Hash(for: matchingCommand)
        return matchingCommandHash == commandHash
    }

}

extension CryptoKit.SHA256.Digest {
    var asString: String {
        let hashString = self.makeIterator().map { value -> String in
            String(format: "%02x", value)
        }
        return hashString.joined()
    }
}
