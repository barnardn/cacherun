import Foundation
import SystemPackage


extension FilePath {
    func isExecutableFile(fileManager: FileManager = .default) -> Bool {
        fileManager.isExecutableFile(atFilePath: self)
    }

    func isFile(fileManager: FileManager = .default) -> Bool {
        fileManager.isReadableFile(atFilePath: self)
    }

    func delete(fileManager: FileManager = .default) throws {
        try fileManager.removeItem(atFilePath: self)
    }

    func isDirectory(fileManager: FileManager = .default) -> Bool {
        fileManager.isDirectory(atFilePath: self)
    }

    func modificationDate(fileManager: FileManager = .default) -> Date? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: string)
            return attributes[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}
