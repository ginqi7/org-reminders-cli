import CommonLibrary
import Foundation

public class SyncLogger {
    private var level: Synchronization.LogLevel
    public var target: Target?
    public var action: Action?
    public var value: Encodable?

    public init(
        level: Synchronization.LogLevel = .info,
        target: Target? = nil,
        action: Action? = nil,
        value: Encodable? = nil
    ) {
        self.level = level
        self.target = target
        self.action = action
        self.value = value
    }

    public enum Target: String {
        case reminders = "macOS Reminders"
        case sqlite = "SQLite"
    }

    public enum Action: String {
        case add = "Add"
        case delete = "Delete"
        case update = "Update"
        case sync = "Sync"
    }

    private func getId() -> String {
        if let list = self.value as? CommonList {
            return list.id ?? ""
        }
        if let reminder = self.value as? CommonReminder {
            return reminder.externalId ?? ""
        }
        return ""
    }

    public func log() {
        guard let action = self.action, let target = self.target, let value = self.value else {
            return
        }

        let time = Date()
        let id = getId()
        let type = String(describing: type(of: value))
        let valueJson = toJson(data: value)

        print("[\(time)][\(target.rawValue)][\(type)][\(action.rawValue)][\(id)]")
        if level == .debug {
            print(valueJson)
        }
    }

    public func toJson(data: Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try? encoder.encode(data)
        return String(data: encoded ?? Data(), encoding: .utf8) ?? ""
    }

    public func debug(_ message: String) {
        if level == .debug {
            print("[DEBUG] \(message)")
        }
    }
}
