import Foundation
import SwiftTreeSitter
import TreeSitterOrg

public class OrgSource {
  var filePath: String
  var source: String = ""
  var headlines: [OrgHeadline] = []
  var tree: MutableTree? = nil
  var language = Language(language: tree_sitter_org())
  var parser = Parser()

  public enum QueryType: String {
    case id
    case info
  }

  public init(filePath: String) throws {
    self.filePath = filePath
    try self.parser.setLanguage(self.language)
    self.source = readFileContents(atPath: self.filePath) ?? ""
  }

  public func measureTime(name: String, block: () throws -> Void) throws {
    let start = Date()
    try block()
    let end = Date()
    print("[\(name)]方法调用时间：\(end.timeIntervalSince(start)) 秒")
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
    try measureTime(
      name: "refreshTree",
      block: {
        if let treeBound = self.tree?.rootNode?.range.upperBound {
          if treeBound > self.source.count {
            self.tree = parser.parse(self.source)
            return
          }
        }
        // self.tree = parser.parse(self.source)
        self.tree = parser.parse(tree: self.tree, string: self.source)
      })

  }

  /// A description Regresh OrgHeadline
  /// - Parameters:
  ///
  /// - Throws:
  public func refreshOrgHeadlines() throws {
    try refreshTree()
    try measureTime(
      name: "getAllHeadlines",
      block: {
        if let root = self.tree?.rootNode {
          try getAllHeadlines(root: root)
        }
      }
    )
  }

  /// A description Flush new source to file and refresh headlines.
  /// - Parameters:
  ///
  /// - Throws:
  public func flush() throws {
    try self.source.write(toFile: self.filePath, atomically: true, encoding: .utf8)
    try refreshOrgHeadlines()
  }

  /// A description Query Exist Headline
  /// - Parameters:
  ///   - headline: OrgHeadline
  ///   - type: QueryType, default is .id
  ///
  /// - Returns: OrgHeadline?
  public func queryExistHeadline(headline: OrgHeadline, type: QueryType = .id) -> OrgHeadline? {
    switch type {
    case .info:
      return queryExistHeadlineByInfo(headline: headline)
    case .id:
      return queryExistHeadlineById(headline: headline)
    }
  }

  /// A description Query Exist Headline By Info
  /// - Parameter headline: OrgHeadline
  /// - Returns: OrgHeadline?
  public func queryExistHeadlineByInfo(headline: OrgHeadline) -> OrgHeadline? {
    let level = headline.level
    let title = headline.title
    let priority = headline.priority
    let statue = headline.status
    let headlines = headline.level == 1 ? self.headlines : self.getAllH2s()
    return headlines.first { headline in
      title == headline.title
        && priority == headline.priority
        && statue == headline.status
        && level == headline.level
    }
  }

  /// A description Get all Headline2 array
  /// - Parameters:
  ///
  /// - Returns: [OrgHeadline]
  func getAllH2s() -> [OrgHeadline] {
    return self.headlines.map { $0.children }.flatMap { $0 }
  }

  /// A description query exist headline by id
  /// - Parameter headline: OrgHeadline
  /// - Returns: OrgHeadline?
  public func queryExistHeadlineById(headline: OrgHeadline) -> OrgHeadline? {
    let property =
      headline.level == 1 ? OrgPropertyKeys.listId.rawValue : OrgPropertyKeys.externalId.rawValue
    // "LIST-ID" : "EXTERNAL-ID"
    let headlines = headline.level == 1 ? self.headlines : self.getAllH2s()
    if let id = headline.properties[property] {
      return headlines.first { id == $0.properties[property] }
    }
    return nil
  }

  /// A description get Node Range
  /// - Parameter node: Node
  /// - Returns: Range<String.Index>?
  public func getNodeRange(node: Node) -> Range<String.Index>? {
    return nsRangeToRange(nsRange: node.range)
  }

  /// A description Convert NSRange to Range<String.Index>?
  /// - Parameter nsRange: NSRange
  /// - Returns: Range<String.Index>?
  func nsRangeToRange(nsRange: NSRange) -> Range<String.Index>? {
    let source = self.source
    return Range(nsRange, in: source)
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

  /// A description Get all Sections in the children of node.
  /// - Parameter node: Node
  /// - Returns: [Node]
  func getAllSections(node: Node) -> [Node] {
    var sections: [Node] = []
    for i in 0...node.namedChildCount {
      if let child = node.namedChild(at: i) {
        if child.nodeType == "section" {
          sections.append(child)
        }
      }
    }
    return sections
  }

  /// A description get all headline in root.
  /// - Parameter root: Node
  /// - Throws:
  func getAllHeadlines(root: Node) throws {
    let h1Sections: [Node] = getAllSections(node: root)
    for h1Section in h1Sections {
      let headline1 = try toOrgHeadline(from: h1Section)
      let h2Sections = getAllSections(node: h1Section)
      for h2Section in h2Sections {
        let headline2 = try toOrgHeadline(from: h2Section)
        headline2.parent = headline1
        headline1.children.append(headline2)
      }
      headlines.append(headline1)
    }
  }

  /// A description Find child when the type equal `type`
  /// - Parameters:
  ///   - node: Node
  ///   - type: String
  ///
  /// - Returns: Node?
  func findChildUntil(node: Node, type: String) -> Node? {
    for i in 0...node.namedChildCount {
      if let child = node.namedChild(at: i) {
        if child.nodeType == type {
          return child
        }
      }
    }
    return nil
  }

  /// A description Get Node text.
  /// - Parameter node: Node
  /// - Returns: String
  func getNodeText(node: Node) -> String {
    let source = self.source
    if let range = getNodeRange(node: node) {
      return String(source[range])
    }
    return ""
  }

  /// A description Convert node to OrgHeadline
  /// - Parameter from: Node
  /// - Throws:
  /// - Returns: OrgHeadline
  func toOrgHeadline(from: Node) throws -> OrgHeadline {
    let headline = OrgHeadline(node: from)
    guard let tsHeadline = findChildUntil(node: from, type: "headline"),
      let starts = findChildUntil(node: tsHeadline, type: "stars")
    else {
      return headline
    }
    headline.level = starts.range.length
    guard let items = findChildUntil(node: tsHeadline, type: "item") else {
      return headline
    }
    var index = 0
    guard let item = items.child(at: index)

    else {
      return headline
    }
    var itemText = getNodeText(node: item)
    if ["TODO", "DONE"].contains(itemText) {
      headline.status = itemText
      index = index + 1
    }
    guard let item = items.child(at: index)

    else {
      return headline
    }
    itemText = getNodeText(node: item)
    if ["[#A]", "[#B]", "[#C]"].contains(itemText) {
      headline.priority = itemText
      index = index + 1
    }
    guard let item = items.child(at: index),
      let last = items.lastChild
    else {
      return headline
    }
    let source = self.source

    let nsRange = NSRange(
      location: item.range.lowerBound,
      length: last.range.upperBound - item.range.lowerBound)
    guard let range = nsRangeToRange(nsRange: nsRange) else {
      return headline
    }
    itemText = String(source[range])
    headline.title = removeStatisticMarks(from: itemText)
    guard let propertyDrawer = findChildUntil(node: from, type: "property_drawer") else {
      return headline
    }
    for i in 0...propertyDrawer.namedChildCount {
      if let child = propertyDrawer.namedChild(at: i) {
        if let key = child.namedChild(at: 0),
          let value = child.namedChild(at: 1)
        {
          headline.properties[getNodeText(node: key)] = getNodeText(node: value)
        }
      }
    }
    guard let body = findChildUntil(node: from, type: "body") else {
      return headline
    }
    let bodyStr = getNodeText(node: body).trimmingCharacters(in: .whitespacesAndNewlines)
    if !bodyStr.isEmpty {
        headline.content = bodyStr
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
