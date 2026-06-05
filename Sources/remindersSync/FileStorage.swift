import Foundation
import CommonLibrary
import Yams

public enum FileFormat {
    case json
    case yaml
}

public struct FileData: Codable {
    public var lists: [CommonList]
    public var reminders: [CommonReminder]

    public init(lists: [CommonList], reminders: [CommonReminder]) {
        self.lists = lists
        self.reminders = reminders
    }
}

public protocol FileStorage {
    var format: FileFormat { get }
    func load() throws -> FileData
    func save(data: FileData) throws
}

public class JSONFileStorage: FileStorage {
    public let format: FileFormat = .json
    public let filePath: String

    public init(filePath: String) {
        self.filePath = NSString(string: filePath).expandingTildeInPath
    }

    public func load() throws -> FileData {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return FileData(lists: [], reminders: [])
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let decoder = JSONDecoder()
        return try decoder.decode(FileData.self, from: data)
    }

    public func save(data: FileData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(data)
        try encoded.write(to: URL(fileURLWithPath: filePath))
    }
}

public class YAMLFileStorage: FileStorage {
    public let format: FileFormat = .yaml
    public let filePath: String

    public init(filePath: String) {
        self.filePath = NSString(string: filePath).expandingTildeInPath
    }

    public func load() throws -> FileData {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return FileData(lists: [], reminders: [])
        }
        let yamlString = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
        let data = try YAMLDecoder().decode(FileData.self, from: yamlString)
        return data
    }

    public func save(data: FileData) throws {
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(data)
        try yamlString.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
    }
}