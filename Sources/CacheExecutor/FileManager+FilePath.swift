import Foundation
import SystemPackage

public extension FileManager {
    func isExecutableFile(atFilePath fp: FilePath) -> Bool {
        isExecutableFile(atPath: fp.string)
    }

    func isReadableFile(atFilePath fp: FilePath) -> Bool {
        isReadableFile(atPath: fp.string)
    }

    func removeItem(atFilePath fp: FilePath) throws {
        try removeItem(atPath: fp.string)
    }

    func isDirectory(atFilePath fp: FilePath) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileExists(atPath: fp.string, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
