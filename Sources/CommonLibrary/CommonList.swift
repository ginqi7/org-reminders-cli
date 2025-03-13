import Foundation

public class CommonList: Encodable, Hashable {
  public var id: String?
  public var title: String
  public var isDeleted: Bool = false
  public static func == (lhs: CommonList, rhs: CommonList) -> Bool {
    return lhs.id == rhs.id && lhs.title == rhs.title
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(title)
  }

  private enum EncodingKeys: String, CodingKey {
    case id
    case title
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.title, forKey: .title)
    try container.encodeIfPresent(self.id, forKey: .id)
  }

  public func toJson() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(self)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  public init(
    title: String,
    id: String?
  ) {
    self.title = title
    self.id = id
  }

}
