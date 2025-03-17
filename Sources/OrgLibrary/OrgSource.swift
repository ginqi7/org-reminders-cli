import CommonLibrary
import Foundation
import SwiftTreeSitter
import TreeSitterOrg

public class OrgSource {
  var filePath: String
  var source: String = ""
  var headlines: [OrgHeadline] = []
  var commonLists: [CommonList] = []
  var commonReminders: [CommonReminder] = []
  var tree: MutableTree? = nil
  var language = Language(language: tree_sitter_org())
  var parser = Parser()

  public init(filePath: String) throws {
    self.filePath = filePath
    try self.parser.setLanguage(self.language)
    self.source = readFileContents(atPath: self.filePath) ?? ""
  }

  /// A description Get Headlines
  /// - Parameters:
  ///
  /// - Returns:
  public func getHeadlines() -> [OrgHeadline] {
    return self.headlines
  }

  /// A description Refresh Source
  /// - Parameters:
  ///
  /// - Throws:
  public func refreshSource() throws {
    self.source = readFileContents(atPath: self.filePath) ?? ""
  }

  /// A description Refresh Tree
  /// - Parameters:
  ///
  /// - Throws:
  public func refreshTree() throws {
    self.tree = parser.parse(self.source)
  }

  /// A description Regresh OrgHeadline
  /// - Parameters:
  ///
  /// - Throws:
  public func refreshOrgHeadlines() throws {
    try refreshTree()
    if let root = self.tree?.rootNode {
      try getAllHeadlines(root: root)
    }
  }

  /// A description Flush new source to file and refresh headlines.
  /// - Parameters:
  ///
  /// - Throws:
  public func flush() throws {
    try self.source.write(toFile: self.filePath, atomically: false, encoding: .utf8)
    try refreshOrgHeadlines()
  }

  /// A description Flush some headlines to file.
  /// - Parameter headlines: OrgHeadline array
  /// - Throws:
  public func flushHeadlines(headlines: [OrgHeadline]) throws {
    self.source = headlines.map { $0.toOrgStr() }.joined()
    try self.flush()
  }

  /// A description Get all Headline2 array
  /// - Parameters:
  ///
  /// - Returns: [OrgHeadline]
  public func getAllH2s() -> [OrgHeadline] {
    return self.headlines.map { $0.children }.flatMap { $0 }
  }

  /// A description Read content from file.
  /// - Parameter path: String
  /// - Returns: String?
  func readFileContents(atPath path: String) -> String? {
    do {
      let contents = try String(contentsOfFile: path, encoding: .utf8)
      return contents
    } catch {
      print("Error reading file: \(error)")
      return nil
    }
  }

  /// A description get all headline in root.
  /// - Parameter root: Node
  /// - Throws:
  func getAllHeadlines(root: Node) throws {
    self.headlines = []
    let h1Sections: [Node] = root.findChildren(type: OrgTreeSitterType.section)
    for h1Section in h1Sections {
      let headline1 = try toOrgHeadline(from: h1Section)
      let h2Sections = h1Section.findChildren(type: OrgTreeSitterType.section)
      for h2Section in h2Sections {
        let headline2 = try toOrgHeadline(from: h2Section)
        headline2.parent = headline1
        headline1.children.append(headline2)
      }
      headlines.append(headline1)
    }
  }

  /// A description Convert node to OrgHeadline
  /// - Parameter from: Node
  /// - Throws:
  /// - Returns: OrgHeadline
  func toOrgHeadline(from: Node) throws -> OrgHeadline {
    let headline = OrgHeadline()
    guard let tsHeadline = from.findChildUntil(type: OrgTreeSitterType.headline),
      let starts = tsHeadline.findChildUntil(type: OrgTreeSitterType.stars)
    else {
      return headline
    }
    headline.level = starts.range.length
    guard let items = tsHeadline.findChildUntil(type: OrgTreeSitterType.item) else {
      return headline
    }
    var index = 0
    // Optional: TODO DONE
    if let item = items.child(at: index) {
      let itemText = item.getText(source: source)
      if OrgStatus.contains(itemText) {
        headline.status = itemText
        index += 1
      }
    }
    // Optional: Priority: [#A] [#B] [#C]
    if let item = items.child(at: index) {
      let itemText = item.getText(source: source)
      if OrgPriority.contains(itemText) {
        headline.priority = itemText
        index += 1
      }
    }
    // Org Headline title.
    if let item = items.child(at: index),
      let last = items.lastChild,
      let lowerBoundIndex = item.getLowerBoundIndex(source: self.source),
      let upperBoundIndex = last.getUpperBoundIndex(source: self.source)
    {
      let range = lowerBoundIndex..<upperBoundIndex
      headline.title = removeStatisticMarks(from: String(self.source[range]))
    }
    // Optional tags
    if let tags = tsHeadline.findChildUntil(type: OrgTreeSitterType.tags) {
      for i in 0..<tags.namedChildCount {
        if let tagText = tags.namedChild(at: i)?.getText(source: self.source) {
          headline.tags.append(tagText)
        }
      }
    }
    // Optional Plan
    if let plans = from.findChildUntil(type: OrgTreeSitterType.plan) {
      for i in 0..<plans.namedChildCount {
        if let plan = plans.namedChild(at: i),
          let key = plan.namedChild(at: 0)?.getText(source: self.source),
          let value = plan.namedChild(at: 1)?.getText(source: self.source)
        {
          headline.plans[key] = value
        }
      }
    }
    if let propertyDrawer = from.findChildUntil(type: OrgTreeSitterType.property_drawer) {
      for i in 0..<propertyDrawer.namedChildCount {
        if let child = propertyDrawer.namedChild(at: i),
          let key = child.namedChild(at: 0),
          let value = child.namedChild(at: 1)
        {
          headline.properties[key.getText(source: source)] = value.getText(source: source)
        }
      }
    }
    if let body = from.findChildUntil(type: OrgTreeSitterType.body) {
      let trimmedString = body.getText(source: source).trimmingCharacters(
        in: .whitespacesAndNewlines)
      headline.content = trimmedString.isEmpty == true ? nil : trimmedString
    }
    return headline
  }

  /// A description Remove Statistic Marks in string.
  /// - Parameter string: String
  /// - Returns:
  func removeStatisticMarks(from string: String) -> String {
    let pattern = "\\s*\\[\\d+/\\d+\\]$"
    do {
      let regex = try NSRegularExpression(pattern: pattern, options: [])
      let range = NSRange(location: 0, length: string.utf16.count)
      let result = regex.stringByReplacingMatches(
        in: string, options: [], range: range, withTemplate: "")
      return result
    } catch {
      print("\(error)")
      return string
    }
  }

  /// A description Convert Node array to OrgHeadline
  /// - Parameter from: Node array
  /// - Throws:
  /// - Returns:
  func toOrgHeadlines(from: [Node]) throws -> [OrgHeadline] {
    return try from.map({ try toOrgHeadline(from: $0) })
  }

}
