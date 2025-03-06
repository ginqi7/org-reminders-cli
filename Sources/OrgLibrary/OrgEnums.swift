public enum OrgPropertyKeys: String {
  case hash = "HASH"
  case lastModified = "LAST-MODIFIED"
  case listId = "LIST-ID"
  case externalId = "EXTERNAL-ID"
}

public enum OrgTreeSitterType: String {
  case headline = "headline"
  case stars = "stars"
  case item = "item"
  case section = "section"
  case plan = "plan"
  case property_drawer = "property_drawer"
  case body = "body"
  case tags = "tag_list"
}

public enum OrgStatus: String {
  case todo = "TODO"
  case done = "DONE"

  static func contains(_ str: String) -> Bool {
    return [self.todo.rawValue, self.done.rawValue].contains(str)
  }
}

public enum OrgPriority: String {
  case low = "[#C]"
  case medium = "[#B]"
  case high = "[#A]"

  static func contains(_ str: String) -> Bool {
    return [self.low.rawValue, self.medium.rawValue, self.high.rawValue].contains(str)
  }
}

public enum OrgPlan: String {
  case scheduled = "SCHEDULED"
  case closed = "CLOSED"
}

public enum OrgDateFormat: String {
  //public var dateFormat = "
  case scheduled = "<yyyy-MM-dd E HH:mm>"
  case closed = "[yyyy-MM-dd E HH:mm]"
  case other = "yyyy-MM-dd HH:mm:ss"
}
