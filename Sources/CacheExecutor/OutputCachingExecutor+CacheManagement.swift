//
//  File.swift
//  
//
//  Created by Norman Barnard on 3/15/20.
//

import Foundation
import SystemPackage

public extension OutputCachingExecutor.CacheManagement {

    struct CommandInfo: CustomStringConvertible {
        let commandLine: String
        let hash: String
        let lastUpdateDate: Date

        public var description: String {
            "\(hash)\t\(commandLine)\t\(lastUpdateDate)"
        }
    }

    static func resetCache(fileManager: FileManager = .default, havingIdentifier identifier: String?) throws {
        do {
            let cacheFiles = findCacheFiles(fileExtension: "data")
            if let identifier {
                guard let cacheFile = cacheFiles.first(where: { $0.lastComponent?.stem.hasPrefix(identifier) == true }) else {
                    throw CacheExecutorError.fileError(message: "no cache file found with identifier: \(identifier)")
                }
                try cacheFile.delete(fileManager: fileManager)
            } else {
                cacheFiles.forEach {
                    try? $0.delete(fileManager: fileManager)
                }
            }
        } catch let error as NSError {
            throw error
        }
    }

    static func deleteCacheFiles(fileManager: FileManager = .default, havingIdentifier identifier: String?) throws {
        do {
            let cacheFiles = findCacheFiles(prefix: identifier)
            guard cacheFiles.count > 0 else {
                if let identifier {
                    throw CacheExecutorError.fileError(message: "no cache file found with identifier: \(identifier)")
                }
                return
            }
            try cacheFiles.forEach { try fileManager.removeItem(atPath: $0.string) }
        } catch let error as NSError {
            throw error
        }
    }

    static func showCachedCommands() {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd' at 'HH:mm:ss"

        let commandInfo = listCachedCommands()
        guard commandInfo.count > 0 else {
            print ("No cached commands.")
            return
        }
        print (
            [
            "Hash".padding(toLength: 10, withPad: " ", startingAt: 0),
            "Last Run Date".padding(toLength: 20, withPad: " ", startingAt: 0),
            "Command",
            ].joined()
        )
        commandInfo.forEach { cmd in
            let formattedDate = dateFormatter.string(from: cmd.lastUpdateDate)
            print(
                [
                    cmd.hash.padding(toLength: 10, withPad: " ", startingAt: 0),
                    formattedDate.padding(toLength: 20, withPad: " ", startingAt: 0),
                    cmd.commandLine,
                ].joined()
            )
        }
    }

    private static func findCacheFiles(fileManager: FileManager = .default, prefix: String? = nil, fileExtension: String? = nil) -> [FilePath] {
        let runDir = OutputCachingExecutor.Utility.locateRunDirectory()
        do {
            let allFiles = try fileManager.contentsOfDirectory(atPath: runDir.string).map(FilePath.init(_:))
            let cacheFiles = allFiles.filter { filename in

                let passPrefixTest: Bool
                if let prefix = prefix {
                    passPrefixTest = filename.string.hasPrefix(prefix)
                } else {
                    passPrefixTest = true
                }

                let passExtensionTest: Bool
                if let fileExtension = fileExtension {
                    passExtensionTest = filename.extension == fileExtension
                } else {
                    passExtensionTest = true
                }
                return passPrefixTest && passExtensionTest
            }
            return cacheFiles.compactMap { cf in
                cf.lastComponent.flatMap { runDir.appending($0) }
            }
        } catch {
            return []
        }
    }

    private static func listCachedCommands(fileManager: FileManager = .default) -> [CommandInfo] {
        let commandPaths = findCacheFiles(fileManager: fileManager, fileExtension: "cmd")
        guard commandPaths.isNotEmpty else { return [] }
        let commandLines = commandPaths.compactMap { path -> CommandInfo? in
            guard
                let data = fileManager.contents(atPath: path.string),
                let commandLine = String(data: data, encoding: .utf8),
                let modTime = path.modificationDate(fileManager: fileManager),
                let basename = path.lastComponent?.stem
            else {
                return nil
            }
            return CommandInfo(
                commandLine: commandLine,
                hash: String(basename.prefix(7)),
                lastUpdateDate: modTime)
        }
        return commandLines
    }
}

extension Collection {
    var isNotEmpty: Bool {
        !isEmpty
    }
}
