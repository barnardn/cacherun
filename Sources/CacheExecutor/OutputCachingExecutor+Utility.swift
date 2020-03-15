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

    static func findProcess(withPid pid: Int, commandHash: String) throws -> Bool {
        let ps = try Basic.Process.popen(arguments: ["/bin/ps", "-o command=", "-p \(pid)"])
        let matchingCommand = try ps.utf8Output()
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

public extension OutputCachingExecutor.CacheManagement {

    struct CommandInfo: CustomStringConvertible {
        let commandLine: String
        let hash: String
        let lastUpdateDate: Date

        public var description: String {
            "\(hash)\t\(commandLine)\t\(lastUpdateDate)"
        }
    }

    static func showCachedCommands() {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd' at 'HH:mm:ss"

        switch listCachedCommands() {
        case .success(let commandInfo):
            print (
                [
                "Hash".padding(toLength: 10, withPad: " ", startingAt: 0),
                "Last Run Date".padding(toLength: 20, withPad: " ", startingAt: 0),
                "Command"
                ].joined()
            )
            commandInfo.forEach { cmd in
                let formattedDate = dateFormatter.string(from: cmd.lastUpdateDate)
                print(
                    [
                        cmd.hash.padding(toLength: 10, withPad: " ", startingAt: 0),
                        formattedDate.padding(toLength: 20, withPad: " ", startingAt: 0),
                        cmd.commandLine,
                        "\n"
                    ].joined()
                )
            }
        case .failure(let error):
            error.localizedDescription.write(to: Basic.stderrStream)
        }
    }

    private static func listCachedCommands() -> Result<[CommandInfo], NSError> {
        let runDir = OutputCachingExecutor.Utility.locateRunDirectory()
        do {
            let allFiles = try localFileSystem.getDirectoryContents(runDir)
            let commandPaths = allFiles.filter { $0.hasSuffix(".cmd") }.map { AbsolutePath($0, relativeTo: runDir) }
            guard commandPaths.count > 0 else { return .success([]) }
            let commandLines = commandPaths.compactMap { path -> CommandInfo? in
                guard
                    let commandLine = try? localFileSystem.readFileContents(path).cString,
                    let fileInfo = try? localFileSystem.getFileInfo(path)
                else {
                    return nil
                }
                return CommandInfo(
                    commandLine: commandLine,
                    hash: String(path.basenameWithoutExt.prefix(7)),
                    lastUpdateDate: fileInfo.lastModDateInLocalTime)
            }
            return .success(commandLines)
        } catch let error as NSError {
            return .failure(error)
        }
    }
}

extension FileInfo {
    var lastModDateInLocalTime: Date {
        let tzOffset = TimeZone.current.secondsFromGMT()
        return Date(timeIntervalSince1970: TimeInterval(Int(modTime.seconds) + tzOffset))
    }

}
