//
//  File.swift
//  
//
//  Created by Norman Barnard on 2/22/20.
//

import Foundation
import XCTest
import Basic
@testable import CacheExecutor

final class cachExecutorTests: XCTestCase {

    // print the date of jan 1, 1970 at 00:00:00
    let commandPlusArgs: [String] = ["/bin/date", "-u", "-r", "0"]

    var commandBaseFilename: String {
        return try! OutputCachingExecutor.Utility.sha256Hash(for: commandPlusArgs.joined(separator: " "))
    }

    lazy var runDirectory: AbsolutePath = {
        return OutputCachingExecutor.Utility.locateRunDirectory()
    }()

    override func tearDown() {
        let pidFile = AbsolutePath(runDirectory, "\(commandBaseFilename).pid")
        let cacheFile = AbsolutePath(runDirectory, "\(commandBaseFilename).data")
        try! localFileSystem.removeFileTree(pidFile)
        try! localFileSystem.removeFileTree(cacheFile)
    }

    func testCachedExecution() {
        let outputStream = MockOutputByteStream()
        let errorStream = MockOutputByteStream()
        let executor = OutputCachingExecutor(cacheTime: 1, userCommand: commandPlusArgs, outputStream: outputStream, errorStream: errorStream)

        // run the command for the first time, creating the cache file
        if case let .failure(executorError) = executor.runCachedCommand() {
            XCTFail("error running executor \(executorError)")
        }
        XCTAssertEqual(outputStream.trimmedString, "Thu Jan  1 00:00:00 UTC 1970")
        outputStream.reset()

        // inject a different date into the cache file, and expect the executor to return the new cached data
        let cacheFile = AbsolutePath(runDirectory, "\(commandBaseFilename).data")
        try! "Thu Jan  2 00:00:00 UTC 1970\n".write(toFile: cacheFile.pathString, atomically: true, encoding: .utf8)
        if case let .failure(executorError) = executor.runCachedCommand() {
            XCTFail("error running executor \(executorError)")
        }
        XCTAssertEqual(outputStream.trimmedString, "Thu Jan  2 00:00:00 UTC 1970")
        outputStream.reset()

        // wait and let the executor overwrite the stale cache file
        sleep(1)
        if case let .failure(executorError) = executor.runCachedCommand() {
            XCTFail("error running executor \(executorError)")
        }
        XCTAssertEqual(outputStream.trimmedString, "Thu Jan  1 00:00:00 UTC 1970")
    }

    func testUnknownCommandError() {
        let outputStream = MockOutputByteStream()
        let errorStream = MockOutputByteStream()
        let executor = OutputCachingExecutor(cacheTime: 1, userCommand: ["/fake/command"], outputStream: outputStream, errorStream: errorStream)
        switch executor.runCachedCommand() {
        case .failure(let error):
            guard case CacheExecutorError.systemError(_) = error else {
                return XCTFail("expected a system error")
            }
        default:
            XCTFail("expected a system error")
        }
    }

    func testCommandError() {
        let outputStream = MockOutputByteStream()
        let errorStream = MockOutputByteStream()
        let executor = OutputCachingExecutor(cacheTime: 1, userCommand: ["/bin/ls", "i-dont-exist-in-the-fs"], outputStream: outputStream, errorStream: errorStream)
        if case let .failure(executorError) = executor.runCachedCommand() {
            XCTFail("error running executor \(executorError)")
        }
        XCTAssertEqual(errorStream.trimmedString, "ls: i-dont-exist-in-the-fs: No such file or directory")
    }

}

public final class MockOutputByteStream: OutputByteStream {

    /// Contents of the stream.
    private var contents = [UInt8]()

    /// The contents of the output stream.
    ///
    /// - Note: This implicitly flushes the stream.
    public var bytes: ByteString {
        return ByteString(contents)
    }

    public var trimmedString: String {
        return bytes.cString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The current offset within the output stream.
    public final var position: Int {
        return contents.count
    }

    public func write(_ byte: UInt8) {
        contents.append(byte)
    }

    public func reset() {
        contents = [UInt8]()
    }

    public func flush() { }

    public func write<C>(_ bytes: C) where C : Collection, C.Element == UInt8 {
        contents.append(contentsOf: bytes)
    }
}
