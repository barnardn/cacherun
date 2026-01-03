//
//  main.swift
//  cacherun
//
//  Created by Norman Barnard on 2/15/20.
//  Copyright © 2020 normbarnard.com. All rights reserved.
//

import Foundation
import ArgumentParser
import CacheExecutor

@main
struct CacheRun: ParsableCommand {
    static let toolVersion = "2.0.0"

    @Option(name: .shortAndLong, help: "cached output expiration time in seconds")
    var cacheTime: Int = 60
    
    @Flag(name: .shortAndLong, help: "display information about the commands currently cached")
    var listCaches = false

    @Option(name: .shortAndLong, help: "deletes all the files assocated to the command identified by <cacheid>")
    var deleteCache: String?
    
    @Option(name: .shortAndLong, help: "resets the cache files for the command identified by <cacheid>, forcing the command to be executed the next time it's run")
    var resetCache: String?

    // implement our own version and help due to `userCommand` argument
    @Flag(name: .long, help: "Show version and exit")
    var version = false

    @Flag(name: [.customShort("H"), .customLong("show-help")], help: "Show help and exit. NOTE: ignore standard `--help' flag")
    var showHelp = false

    @Argument(parsing: .captureForPassthrough, help: "command <flags> <args>")
    var userCommand: [String] = []
    
    mutating func run() throws {
        // NOTE: we need to handle these args separately as `.captureForPassthrough` swallows the standard --version and --help flags
        guard !version else {
            print(Self.toolVersion)
            throw CleanExit.message("")
        }
        guard !showHelp else {
            throw CleanExit.helpRequest(self)
        }

        if listCaches {
            OutputCachingExecutor.CacheManagement.showCachedCommands()
        } else if let deleteCache = deleteCache {
            try OutputCachingExecutor.CacheManagement.deleteCacheFiles(havingIdentifier: deleteCache)
        } else if let resetCache = resetCache {
            try OutputCachingExecutor.CacheManagement.resetCache(havingIdentifier: resetCache)
        } else {
            guard !userCommand.isEmpty else {
                throw CleanExit.helpRequest(self)
            }
            
            let executor = OutputCachingExecutor(cacheTime: cacheTime, userCommand: userCommand)
            if case let .failure(executorError) = executor.runCachedCommand() {
                
                defer { CacheRun.exit(withError: executorError) }
                
                switch executorError {
                case .badCommand(let reason),
                     .fileError(let reason),
                     .hashFailure(let reason):
                    try? FileHandle.standardError.write(contentsOf: Data(reason.utf8))
                case .systemError(let error):
                    try? FileHandle.standardError.write(contentsOf: Data(error.localizedDescription.utf8))
                }
                
            }
        }
    }
}

