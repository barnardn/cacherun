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
    optional: false,
    strategy: .remaining,
    usage: "command arg0 arg1 ... argn",
    completion: ShellCompletion.none
)

let argv = Array(CommandLine.arguments.dropFirst())

do {
    let parsedArgs = try argParser.parse(argv)
    guard let cacheTime = parsedArgs.get(cacheTimeArg) else {
        print("Supply a cache time in seconds.")
        exit(1)
    }
    guard let userCommand = parsedArgs.get(userCommandArgs) else {
        print("Supply a command to run.")
        exit(1)
    }

    print("cache time \(cacheTime)")
    print("user command: \(userCommand.joined(separator: " "))")

    let executor = CacheExecutor(cacheTime: cacheTime, userCommand: userCommand)

    try executor.runCachedCommand()

    readLine()

} catch {
    print(error.localizedDescription)
    argParser.printUsage(on: Basic.stderrStream)
    exit(1)
}
