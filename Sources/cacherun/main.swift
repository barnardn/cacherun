//
//  main.swift
//  cacherun
//
//  Created by Norman Barnard on 2/15/20.
//  Copyright © 2020 normbarnard.com. All rights reserved.
//

import Foundation
import TSCBasic
import ArgumentParser
import CacheExecutor

struct CacheRun: ParsableCommand {
    
    @Option(name: .shortAndLong, help: "cached output expiration time in seconds")
    var cacheTime: Int = 60
    
    @Flag(name: .shortAndLong, help: "display information about the commands currently cached")
    var listCaches = false

    @Flag(name: .shortAndLong)
    var help: Bool = false
    
    @Option(name: .shortAndLong, help: "deletes all the files assocated to the command identified by <cacheid>")
    var deleteCache: String?
    
    @Option(name: .shortAndLong, help: "resets the cache files for the command identified by <cacheid>, forcing the command to be executed the next time it's run")
    var resetCache: String?
    
    @Argument(parsing: .unconditionalRemaining, help: "command <flags> <args>")
    var userCommand: [String] = []
    
    mutating func run() throws {
            
        guard !help else { throw CleanExit.helpRequest(self) }
        
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
                    reason.write(to: TSCBasic.stderrStream)
                case .systemError(let error):
                    error.localizedDescription.write(to: TSCBasic.stderrStream)
                }
                
            }
        }
    }
}

if #available(OSX 10.15, *) {
    CacheRun.main()
} else {
    print("Update to a macos 10.15 or better")
    exit(1)
}
