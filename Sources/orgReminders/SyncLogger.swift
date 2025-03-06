import CommonLibrary
import Foundation

public class SyncLogger {
  var level: LogLevel
  var target: Target?
  var action: Action?
  var value: Encodable?

  public init(
    level: LogLevel,
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
    case reminders = "MacOS Reminders"
    case org = "Org Mode"
  }

  public enum Action: String {
    case add = "Add"
    case delete = "Delete"
    case update = "Update"
  }

  func getId() -> String {
    if let list = self.value as? CommonList {
      return list.id ?? ""
    }
    if let reminder = self.value as? CommonReminder {
      return reminder.externalId ?? ""
    }
    return ""
  }

  public func log() {
    let time = Date()
    let id = self.getId()
    let action = self.action!.rawValue
    let target = self.target!.rawValue
    let value = self.value!
    let type = type(of: self.value!)
    let valueJson = toJson(data: value)
    let base64 = toBase64(originalString: valueJson) ?? ""
    print("[\(time)][\(target)][\(type)][\(action)][\(id)][\(base64)]")
    if level == .debug {
      print(valueJson)
    }
  }

  func toBase64(originalString: String) -> String? {
    return originalString.data(using: .utf8)?.base64EncodedString()
  }

  public func toJson(data: Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(data)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

}
