//
//  File.swift
//  
//
//  Created by Norman Barnard on 3/15/20.
//

import Foundation
import Basic

public extension OutputCachingExecutor.CacheManagement {

    struct CommandInfo: CustomStringConvertible {
        let commandLine: String
        let hash: String
        let lastUpdateDate: Date

        public var description: String {
            "\(hash)\t\(commandLine)\t\(lastUpdateDate)"
        }
    }

    static func resetCache(havingIdentifier identifier: String) -> Result<Bool, NSError> {
        do {
            guard let cacheFile = findCacheFiles(prefix: identifier, fileExtension: "data").first else {
                return .failure(NSError(domain: "cacherun", code: 1, userInfo: [NSLocalizedDescriptionKey: "no cache file found with identifier: \(identifier)"]))
            }
            try localFileSystem.removeFileTree(cacheFile)
            return .success(true)
        } catch let error as NSError {
            return .failure(error)
        }
    }

    static func deleteCacheFiles(havingIdentifier identifier: String) -> Result<Bool, NSError> {
        do {
            let cacheFiles = findCacheFiles(prefix: identifier)
            guard cacheFiles.count > 0 else {
                return .failure(NSError(domain: "cacherun", code: 1, userInfo: [NSLocalizedDescriptionKey: "no cache file found with identifier: \(identifier)"]))
            }
            try cacheFiles.forEach { try localFileSystem.removeFileTree($0) }
            return .success(true)
        } catch let error as NSError {
            return .failure(error)
        }
    }

    static func showCachedCommands() {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd' at 'HH:mm:ss"

        let commandInfo = listCachedCommands()
        guard commandInfo.count > 0 else { return }
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
    }

    private static func findCacheFiles(prefix: String? = nil, fileExtension: String? = nil) -> [AbsolutePath] {

        let runDir = OutputCachingExecutor.Utility.locateRunDirectory()
        do {
            let allFiles = try localFileSystem.getDirectoryContents(runDir)
            let cacheFiles = allFiles.filter { (filename: String) in

                let passPrefixTest: Bool
                if let prefix = prefix {
                    passPrefixTest = filename.hasPrefix(prefix)
                } else {
                    passPrefixTest = true
                }

                let passExtensionTest: Bool
                if let fileExtension = fileExtension {
                    let ext = fileExtension.hasPrefix(".") ? fileExtension : ".\(fileExtension)"
                    passExtensionTest = filename.hasSuffix(ext)
                } else {
                    passExtensionTest = true
                }
                return passPrefixTest && passExtensionTest
            }
            return cacheFiles.map { AbsolutePath($0, relativeTo: runDir) }
        } catch {
            return []
        }
    }

    private static func listCachedCommands() -> [CommandInfo] {
        let commandPaths = findCacheFiles(fileExtension: ".cmd")
        guard commandPaths.count > 0 else { return [] }
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
        return commandLines
    }
}

extension FileInfo {
    var lastModDateInLocalTime: Date {
        let tzOffset = TimeZone.current.secondsFromGMT()
        return Date(timeIntervalSince1970: TimeInterval(Int(modTime.seconds) + tzOffset))
    }

}
