import Foundation

public final class CommonList: Codable, Hashable {
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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: EncodingKeys.self)
    self.id = try container.decodeIfPresent(String.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
  }

  public init(
    title: String,
    id: String?
  ) {
    self.title = title
    self.id = id
  }

}
