//
//  main.swift
//  cacherun
//
//  Created by Norman Barnard on 2/15/20.
//  Copyright © 2020 normbarnard.com. All rights reserved.
//

import Foundation
import SPMUtility
import Basic
import CacheExecutor

let argParser = ArgumentParser(
    commandName: "cacherun",
    usage: "--cache-time 60 command <flags> <args>",
    overview: "Returns the cached output of \"commmand\" when executed within \"--cache-time\" seconds"
)
let cacheTimeArg = argParser.add(
    option: "--cache-time",
    shortName: "-c",
    kind: Int.self,
    usage: "cached output expiration time in seconds",
    completion: ShellCompletion.none
)
let userCommandArgs = argParser.add(
    positional: "command",
    kind: [String].self,
    optional: true,
    strategy: .remaining,
    usage: "command arg0 arg1 ... argn",
    completion: ShellCompletion.none
)

let listCachesOption = argParser.add(
    option: "--list-caches",
    shortName: "-l",
    kind: Bool.self,
    usage: "display information about the command currently cached",
    completion: ShellCompletion.none
)

let resetCacheOption = argParser.add(
    option: "--reset-cache",
    shortName: "-r",
    kind: String.self,
    usage: "resets the cache files for the command identified by <cacheid>, forcing the command to be executed the next time it's run",
    completion: ShellCompletion.none
)

let deleteCacheOption = argParser.add(
    option: "--delete-cache",
    shortName: "-d",
    kind: String.self,
    usage: "deletes all the files assocated to the command identified by <cacheid>",
    completion: ShellCompletion.none
)

let argv = Array(CommandLine.arguments.dropFirst())

do {
    let parsedArgs = try argParser.parse(argv)

    if let listCommand = parsedArgs.get(listCachesOption), listCommand == true {
        guard argv.count == 1 else {
            argParser.printUsage(on: Basic.stderrStream)
            exit(EXIT_FAILURE)
        }
        OutputCachingExecutor.CacheManagement.showCachedCommands()
        exit(EXIT_SUCCESS)
    } else if let commandHash = parsedArgs.get(resetCacheOption) {
        guard argv.count == 2 else {
            argParser.printUsage(on: Basic.stderrStream)
            exit(EXIT_FAILURE)
        }
        if case .failure(let error) = OutputCachingExecutor.CacheManagement.resetCache(havingIdentifier: commandHash) {
            error.localizedDescription.write(to: Basic.stderrStream)
            exit(EXIT_FAILURE)
        }
        exit(EXIT_SUCCESS)
    } else if let commandHash = parsedArgs.get(deleteCacheOption) {
        guard argv.count == 2 else {
            argParser.printUsage(on: Basic.stderrStream)
            exit(EXIT_FAILURE)
        }
        if case .failure(let error) = OutputCachingExecutor.CacheManagement.deleteCacheFiles(havingIdentifier: commandHash) {
            error.localizedDescription.write(to: Basic.stderrStream)
            exit(EXIT_FAILURE)
        }
        exit(EXIT_SUCCESS)
    }

    guard let cacheTime = parsedArgs.get(cacheTimeArg) else {
        print("Supply a cache time in seconds.")
        exit(EXIT_FAILURE)
    }
    guard let userCommand = parsedArgs.get(userCommandArgs) else {
        print("Supply a command to run.")
        exit(EXIT_FAILURE)
    }

    let executor = OutputCachingExecutor(cacheTime: cacheTime, userCommand: userCommand)

    if case let .failure(executorError) = executor.runCachedCommand() {
        switch executorError {
        case .badCommand(let reason):
            reason.write(to: Basic.stderrStream)
        case .hashFailure(let message):
            message.write(to: Basic.stderrStream)
        case .systemError(let error):
            error.localizedDescription.write(to: Basic.stderrStream)
        }
        exit(EXIT_FAILURE)
    }

} catch {
    print(error.localizedDescription)
    argParser.printUsage(on: Basic.stderrStream)
    exit(EXIT_FAILURE)
}
