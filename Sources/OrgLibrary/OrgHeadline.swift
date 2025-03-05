import Foundation
import SwiftTreeSitter

public class OrgHeadline: Encodable {
  public var level: Int
  public var title: String
  public var status: String?
  public var priority: String?
  public var scheduled: String?
  public var closed: String?
  public var properties: [String: String]
  public var children: [OrgHeadline]
  public var parent: OrgHeadline?
  public var content: String?
  public var node: Node?

  private enum EncodingKeys: String, CodingKey {
    case level
    case title
    case status
    case priority
    case scheduled
    case closed
    case properties
    case children
    case parent
    case content
    case begin
    case end
  }

  public init(
    level: Int = 1,
    title: String = "",
    status: String? = nil,
    priority: String? = nil,
    scheduled: String? = nil,
    closed: String? = nil,
    properties: [String: String] = [:],
    children: [OrgHeadline] = [],
    node: Node? = nil,
    content: String? = nil
  ) {
    self.level = level
    self.title = title
    self.status = status
    self.priority = priority
    self.scheduled = scheduled
    self.closed = closed
    self.properties = properties
    self.children = children
    self.node = node
    self.content = content
  }

  /// A description Compute an hash value to identify a Headline.
  /// - Parameters:
  ///
  /// - Returns: String
  public func computeHash() -> String {
    let status = self.status ?? ""
    let priority = self.priority ?? ""
    let scheduled = self.scheduled ?? ""
    let closed = self.closed ?? ""
    let content = self.content ?? ""
    return sha256Hash("\(level):\(title):\(status)\(priority)\(scheduled)\(closed)\(content)")
  }

  /// A description Checks if a headline has been modified.
  /// Modification will update the last modified time.
  /// - Parameters:
  ///
  /// - Returns: new Hash or nil
  public func modified() -> String? {
    if self.level == 1 {
      return nil
    }
    if let hash = self.properties["HASH"] {
      let newHash = computeHash()
      if String(describing: hash) == newHash {
        return nil
      }
      return newHash
    }
    return nil
  }

  /// A description
  /// - Parameter encoder:
  /// - Throws:
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.level, forKey: .level)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.status, forKey: .status)
    try container.encode(self.priority, forKey: .priority)
    try container.encode(self.scheduled, forKey: .scheduled)
    try container.encode(self.closed, forKey: .closed)
    try container.encode(self.properties, forKey: .properties)
    try container.encode(self.content, forKey: .content)
    try container.encode(self.parent, forKey: .parent)
  }

  /// A description Convert to json string
  /// - Parameters:
  ///
  /// - Returns:
  public func toJson() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(self)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  /// A description Count Statistics
  /// - Parameters:
  ///
  /// - Returns:
  func countStatistics() -> String {
    if self.level != 1 {
      return ""
    }
    let todo = self.children.count { headline in
      headline.status == "TODO"
    }
    let done = self.children.count { headline in
      headline.status == "DONE"
    }
    return " [\(done)/\(todo+done)]"
  }

  /// A description Convert org to string
  /// - Parameters:
  ///
  /// - Returns:
  public func toOrgStr() -> String {
    let stars = self.level == 1 ? "\n*" : "\n**"
    let status = self.status == nil ? "" : " \(self.status!)"
    let closed = self.closed == nil ? "" : "\n\(self.closed!)"
    let content = self.content == nil ? "" : "\n\(self.content!)"
    let priority = self.priority == nil ? "" : " [#\(self.priority!)]"
    let title = " \(self.title)"
    let todoStatistics = countStatistics()
    var properties = self.properties.map { (key: String, value: String) in
      return "\n:\(key): \(value)"
    }.joined()
    let subheadlines = self.children.map { subheadline in
      return subheadline.toOrgStr()
    }.joined()
    properties = properties == "" ? "" : "\n:PROPERTIES:\(properties)\n:END:"
    return
      "\(stars)\(status)\(priority)\(title)\(todoStatistics)\(closed)\(properties)\(content)\(subheadlines)"
  }
}
