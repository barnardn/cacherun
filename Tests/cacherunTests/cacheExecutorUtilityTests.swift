//
//  cachExecutorUtilityTests.swift
//  
//
//  Created by Norman Barnard on 2/17/20.
//

import Foundation
import XCTest
import TSCBasic
@testable import CacheExecutor

final class cachExecutorUtilityTests: XCTestCase {

    let fullPath = "/usr/bin:/usr/local/bin:/bin:/opt/bin"

    func testFindCommand() {
        let lsExists = OutputCachingExecutor.Utility.findCommand(command: "ls", pathEnvironmentValue: fullPath)
        XCTAssertEqual(lsExists?.pathString, "/bin/ls")

        let lsNotExist = OutputCachingExecutor.Utility.findCommand(command: "ls", pathEnvironmentValue: "/usr/bin:/usr/local/bin:/opt/bin")
        XCTAssertNil(lsNotExist)

        XCTAssertNil(OutputCachingExecutor.Utility.findCommand(command: "ls", pathEnvironmentValue: nil))

        let fullPathCommand = OutputCachingExecutor.Utility.findCommand(command: "/bin/ls", pathEnvironmentValue: fullPath)
        XCTAssertEqual(fullPathCommand?.pathString, "/bin/ls")

        let fakeCommand = OutputCachingExecutor.Utility.findCommand(command: "not-a-real-command", pathEnvironmentValue: fullPath)
        XCTAssertNil(fakeCommand)

        let badFullPath = OutputCachingExecutor.Utility.findCommand(command: "ends/in/slash", pathEnvironmentValue:fullPath )
        XCTAssertNil(badFullPath)
    }

    func testSha256Hash() {
        let knownHash = "7e3486e5ce8bb7e869725d154a240090c139e335f182fbc5618177165ebaf2c1"
        let cmd = "this is a command to checksum"
        let computedHash = try? OutputCachingExecutor.Utility.sha256Hash(for: cmd)
        XCTAssertEqual(computedHash, knownHash)
    }

    func testIsStaleFile() {
        let testFilePath = AbsolutePath("/tmp/test.txt")

        defer { try? localFileSystem.removeFileTree(testFilePath) }

        try? "test-test-test".write(toFile: testFilePath.pathString, atomically: true, encoding: .utf8)
        sleep(1)
        XCTAssertFalse(OutputCachingExecutor.Utility.isStaleFile(at: testFilePath, maxAgeInSeconds: 10))
        sleep(2)
        XCTAssertTrue(OutputCachingExecutor.Utility.isStaleFile(at: testFilePath, maxAgeInSeconds: 2))
    }

}
