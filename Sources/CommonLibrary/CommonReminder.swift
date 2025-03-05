import Foundation

public class CommonReminder: Encodable {
  public var title: String
  public var externalId: String?
  public var priority: Int
  public var isCompleted: Bool
  public var isDeleted: Bool
  public var dueDate: Date?
  public var completionDate: Date?
  public var lastModified: Date?
  public var list: CommonList
  public var listName: String
  public var listId: String
  public var notes: String?

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
    case listId
    case listName
    case list
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encodeIfPresent(self.externalId, forKey: .externalId)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.isCompleted, forKey: .isCompleted)
    try container.encode(self.priority, forKey: .priority)
    try container.encode(self.listId, forKey: .listId)
    try container.encode(self.listName, forKey: .listName)
    try container.encode(self.list, forKey: .list)
    try container.encodeIfPresent(self.completionDate, forKey: .completionDate)
    try container.encodeIfPresent(self.notes, forKey: .notes)
    try container.encodeIfPresent(self.dueDate, forKey: .dueDate)
    try container.encodeIfPresent(dateToStr(date: self.lastModified), forKey: .lastModified)
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
    listName: String = "",
    listId: String = "",
    externalId: String? = nil,
    priority: Int = 0,
    isCompleted: Bool = false,
    isDeleted: Bool = false,
    dueDate: Date? = nil,
    completionDate: Date? = nil,
    lastModified: Date = Date(),
    notes: String = ""
  ) {
    self.title = title
    self.list = list
    self.listId = listId
    self.listName = listName
    self.externalId = externalId
    self.priority = priority
    self.isCompleted = isCompleted
    self.isDeleted = isDeleted
    self.dueDate = dueDate
    self.completionDate = completionDate
    self.lastModified = lastModified

    self.notes = notes
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
