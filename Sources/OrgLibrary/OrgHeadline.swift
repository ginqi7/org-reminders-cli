import Foundation

public class OrgHeadline: Encodable {
  public var level: Int
  public var title: String
  public var status: String?
  public var priority: String?
  public var plans: [String: String]
  public var properties: [String: String]
  public var tags: [String]
  public var children: [OrgHeadline]
  public var parent: OrgHeadline?
  public var content: String?

  private enum EncodingKeys: String, CodingKey {
    case level
    case title
    case status
    case priority
    case plans
    case properties
    case children
    case parent
    case content
  }

  public init(
    level: Int = 1,
    title: String = "",
    status: String? = nil,
    priority: String? = nil,
    plans: [String: String] = [:],
    properties: [String: String] = [:],
    tags: [String] = [],
    children: [OrgHeadline] = [],
    content: String? = nil
  ) {
    self.level = level
    self.title = title
    self.status = status
    self.priority = priority
    self.plans = plans
    self.properties = properties
    self.children = children
    self.content = content
    self.tags = tags
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
    try container.encode(self.plans, forKey: .plans)
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
    let content = self.content == nil ? "" : "\n\(self.content!)"
    let priority = self.priority == nil ? "" : " [#\(self.priority!)]"
    let title = " \(self.title)"
    let todoStatistics = countStatistics()
    // CLOSED: [2025-03-10 Mon 13:18]
    // SCHEDULED: <2025-03-10 Mon>
    var plans = self.plans.map { "\($0.key): \($0.value)" }.joined(separator: " ")
    plans = plans == "" ? "" : "\n\(plans)"
    // :PROPERTIES:
    // :HASH: a253e0767a221a52085dfe9ab30b8705b9f0ac82af831db3f22c6774bc5ef903
    // :EXTERNAL-ID: F5F608AB-68B2-4B16-BDA2-10176FFF1301
    // :LAST-MODIFIED: 2025-03-08 16:36:34
    // :END:
    var properties = self.properties.map { "\n:\($0.key): \($0.value)" }.joined()
    properties = properties == "" ? "" : "\n:PROPERTIES:\(properties)\n:END:"
    let subheadlines = self.children.map { subheadline in
      return subheadline.toOrgStr()
    }.joined()

    return
      "\(stars)\(status)\(priority)\(title)\(todoStatistics)\(plans)\(properties)\(content)\(subheadlines)"
  }
}
