//
//  File.swift
//  
//
//  Created by Norman Barnard on 2/22/20.
//

import Foundation
import XCTest
import SystemPackage
@testable import CacheExecutor

final class cachExecutorTests: XCTestCase {

    // print the date of jan 1, 1970 at 00:00:00
    let commandPlusArgs: [String] = ["/bin/date", "-u", "-r", "0"]

    var commandBaseFilename: String {
        return try! OutputCachingExecutor.Utility.sha256Hash(for: commandPlusArgs.joined(separator: " "))
    }

    lazy var runDirectory: FilePath = {
        return OutputCachingExecutor.Utility.locateRunDirectory()
    }()

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
        let cacheFile = runDirectory.appending("\(commandBaseFilename).data")
        try! "Thu Jan  2 00:00:00 UTC 1970\n".write(toFile: cacheFile.string, atomically: true, encoding: .utf8)
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

        let pidFile = runDirectory.appending("\(commandBaseFilename).pid")
        let cmdFile = runDirectory.appending("\(commandBaseFilename).cmd")
        XCTAssertFalse(pidFile.isFile())
        try! cmdFile.delete()
        try! cacheFile.delete()
    }

    func testUnknownCommandError() {
        let outputStream = MockOutputByteStream()
        let errorStream = MockOutputByteStream()
        let executor = OutputCachingExecutor(cacheTime: 1, userCommand: ["/fake/command"], outputStream: outputStream, errorStream: errorStream)
        switch executor.runCachedCommand() {
        case .failure(let error):
            guard case CacheExecutorError.badCommand(_) = error else {
                return XCTFail("expected a bad command error")
            }
        default:
            XCTFail("expected a system error")
        }
        let pidFile = runDirectory.appending("\(commandBaseFilename).pid")
        let cacheFile = runDirectory.appending("\(commandBaseFilename).data")
        let cmdFile = runDirectory.appending("\(commandBaseFilename).cmd")
        XCTAssertFalse(pidFile.isFile())
        XCTAssertFalse(cacheFile.isFile())
        XCTAssertFalse(cmdFile.isFile())
    }

    func testCommandError() {
        let outputStream = MockOutputByteStream()
        let errorStream = MockOutputByteStream()
        let commandPlusArgs = ["/bin/ls", "i-dont-exist-in-the-fs"]
        let executor = OutputCachingExecutor(cacheTime: 1, userCommand: commandPlusArgs, outputStream: outputStream, errorStream: errorStream)
        if case let .failure(executorError) = executor.runCachedCommand() {
            XCTFail("error running executor \(executorError)")
        }
        XCTAssertEqual(errorStream.trimmedString, "ls: i-dont-exist-in-the-fs: No such file or directory")

        let commandBaseFilename = try! OutputCachingExecutor.Utility.sha256Hash(for: commandPlusArgs.joined(separator: " "))
        let pidFile = runDirectory.appending("\(commandBaseFilename).pid")
        let cacheFile = runDirectory.appending("\(commandBaseFilename).data")
        let cmdFile = runDirectory.appending("\(commandBaseFilename).cmd")
        XCTAssertFalse(pidFile.isFile())
        try! cmdFile.delete()
        try! cacheFile.delete()
    }

}
public final class MockOutputByteStream: Utf8TextOutputStream {
    /// Contents of the stream.
    private let contents = LockIsolated(String())

    public var trimmedString: String {
        contents.update {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// The current offset within the output stream.
    public final var position: Int {
        return contents.get().count
    }

    public func write(_ string: String) {
        contents.update {
            $0.appending(string)
        }
    }

    public func reset() {
        contents.set("")
    }

    public func flush() { }
}

final class LockIsolated<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    @discardableResult
    func update(_ closure: (T) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        value = closure(value)
        return value
    }

}
