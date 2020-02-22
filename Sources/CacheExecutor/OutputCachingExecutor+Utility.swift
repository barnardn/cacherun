//
//  File.swift
//  
//
//  Created by Norman Barnard on 2/17/20.
//

import Foundation
import Basic
import CryptoKit

extension OutputCachingExecutor.Utility {

    /// Locate `command` in the user's path verifying that it's executable. If there are multiple
    /// executable commands found, return the first one.
    /// - Parameter command: file name of the sought after command
    ///
    static func findCommand(command: String, pathEnvironmentValue: String?) -> AbsolutePath? {
        guard let pathEnvironmentVar = pathEnvironmentValue else { return nil }

        // command contains a separator, assume it's a full path
        if let commandIsPath = try? AbsolutePath(validating: command) {
            return commandIsPath
        }
        let pathDirs = pathEnvironmentVar.components(separatedBy: ":")

        return pathDirs.compactMap { path -> AbsolutePath? in
            guard let pathAbs = try? AbsolutePath(validating: path) else { return nil }
            return AbsolutePath(pathAbs, command)
        }.filter { candidatePath -> Bool in
            localFileSystem.isExecutableFile(candidatePath)
        }.first
    }

    static func sha256Hash(for string: String) throws -> String {
        guard let stringData = string.data(using: .utf8) else { throw CacheExecutorError.hashFailure(string) }
        return SHA256.hash(data: stringData).asString
    }

    static func isStaleFile(at path: AbsolutePath, maxAgeInSeconds maxAge: TimeInterval) -> Bool {
        guard let fileAttributes = try? localFileSystem.getFileInfo(path) else { return true }
        return Date().timeIntervalSince1970 - TimeInterval(fileAttributes.modTime.seconds) > maxAge
    }

    static func locateRunDirectory() -> AbsolutePath {
        guard
            let appSupportURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else {
            return AbsolutePath("/tmp")
        }
        let appSupportPath = AbsolutePath(appSupportURL.path)
        return appSupportPath.appending(components: "cacherun")
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
