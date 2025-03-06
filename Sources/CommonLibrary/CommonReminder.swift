import Foundation

public class CommonReminder: Encodable {
  public var title: String
  public var externalId: String?
  public var priority: Int
  public var isCompleted: Bool
  public var isDeleted: Bool
  public var dueDate: CommonDate?
  public var completionDate: CommonDate?
  public var lastModified: CommonDate?
  public var list: CommonList
  public var notes: String?
  public var hash: String?

  private enum EncodingKeys: String, CodingKey {
    case externalId
    case lastModified
    case creationDate
    case title
    case notes
    case url
    case location
    case locationTitle
    case completionDate
    case isCompleted
    case priority
    case startDate
    case dueDate
    case list
    case hash
  }

  /// A description Compute an hash value to identify a Headline.
  /// - Parameters:
  ///
  /// - Returns: String
  public func computeHash() -> String {
    let title = self.title
    let isCompleted = self.isCompleted
    let isDeleted = self.isDeleted
    let dueDate = String(describing: self.dueDate)
    let notes = self.notes ?? ""
    return sha256Hash("\(title)\(priority)\(isCompleted)\(isDeleted)\(dueDate)\(notes)")
  }

  /// A description Checks if a headline has been modified.
  /// Modification will update the last modified time.
  /// - Parameters:
  ///
  /// - Returns: new Hash or nil
  public func modified() -> String? {
    let newHash = computeHash()
    if self.hash == newHash {
      return nil
    }
    return newHash
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encodeIfPresent(self.externalId, forKey: .externalId)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.isCompleted, forKey: .isCompleted)
    try container.encode(self.priority, forKey: .priority)
    try container.encode(self.list, forKey: .list)
    try container.encode(self.hash, forKey: .hash)
    try container.encodeIfPresent(self.completionDate?.dateText, forKey: .completionDate)
    try container.encodeIfPresent(self.dueDate?.dateText, forKey: .dueDate)
    try container.encodeIfPresent(self.lastModified?.dateText, forKey: .lastModified)
    try container.encodeIfPresent(self.notes, forKey: .notes)

  }

  public func toJson() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(self)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  public init(
    title: String,
    list: CommonList,
    externalId: String? = nil,
    priority: Int = 0,
    isCompleted: Bool = false,
    completionDate: CommonDate? = nil,
    dueDate: CommonDate? = nil,
    lastModified: CommonDate = CommonDate(),
    isDeleted: Bool = false,
    notes: String? = nil,
    hash: String? = nil
  ) {
    self.title = title
    self.list = list
    self.externalId = externalId
    self.priority = priority
    self.isCompleted = isCompleted
    self.isDeleted = isDeleted
    self.dueDate = dueDate
    self.completionDate = completionDate
    self.lastModified = lastModified
    self.notes = notes
    self.hash = hash
  }

  func dateToStr(date: Date?) -> String? {
    guard let date = date else {
      return nil
    }
    let dateFormat = "yyyy-MM-dd HH:mm:ss"
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = dateFormat
    return dateFormatter.string(from: date)
  }

}
