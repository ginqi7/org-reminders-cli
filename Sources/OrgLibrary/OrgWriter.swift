import CommonLibrary
import Foundation

public class OrgWriter {
  var filePath: String
  var orgSource: OrgSource

  /// A description Delete headline in org file.
  /// - Parameter headline: OrgHeadline
  /// - Throws:
  public func deleteHeadline(headline: OrgHeadline) throws {
    guard let node = headline.node,
      let range = self.orgSource.getNodeRange(node: node)
    else {
      return
    }
    self.orgSource.source.replaceSubrange(range, with: "")
    try self.orgSource.flush()
  }

  /// A description Add Headline in position.
  /// - Parameters:
  ///   - headline: OrgHeadline
  ///   - position: String.Index
  ///
  /// - Throws:
  public func addHeadline(headline: OrgHeadline, position: String.Index) throws {
    self.orgSource.source.insert(contentsOf: "\n" + headline.toOrgStr(), at: position)
    try self.orgSource.flush()
  }

  /// A description Flush some headlines to file.
  /// - Parameter headlines: OrgHeadline array
  /// - Throws:
  public func flushHeadlines(headlines: [OrgHeadline]) throws {
    self.orgSource.source = headlines.map { $0.toOrgStr() }.joined()
    try self.orgSource.flush()
  }

  /// A description Write a headline
  /// - Parameter headline: OrgHeadline
  /// - Throws:
  public func addHeadline(headline: OrgHeadline) throws {
    if let parent = headline.parent,
      let existParent = self.orgSource.queryExistHeadline(headline: parent),
      let upperBound = existParent.node?.range.upperBound
    {
      let index = self.orgSource.source.index(
        self.orgSource.source.startIndex, offsetBy: upperBound)
      return try addHeadline(headline: headline, position: index)
    }
    return try addHeadline(headline: headline, position: self.orgSource.source.endIndex)
  }

  /// A description Update Headline in file.
  /// - Parameter headline: OrgHeadline
  /// - Throws:
  public func updateHeadline(headline: OrgHeadline) throws {
    guard let node = headline.node,
      var range = self.orgSource.getNodeRange(node: node)
    else {
      return
    }
    if let firstChild = self.orgSource.getAllSections(node: node).first,
      let firstChildRange = self.orgSource.getNodeRange(node: firstChild)
    {
      let lowerBound = range.lowerBound
      let upperBound = firstChildRange.upperBound
      range = lowerBound..<upperBound
    }
    let lowerBound = self.orgSource.source.index(range.lowerBound, offsetBy: -1)
    let upperBound = self.orgSource.source.index(range.upperBound, offsetBy: -1)
    range = lowerBound..<upperBound
    self.orgSource.source.replaceSubrange(range, with: headline.toOrgStr())
    try self.orgSource.flush()
  }

  /// A description Update hash of item in the file.
  /// - Parameters:
  ///
  /// - Throws:
  public func updateHash(modifiedDate: String?) throws {

    try self.orgSource.refreshSource()
    try self.orgSource.refreshOrgHeadlines()
    for headline in self.orgSource.headlines {
      for h2 in headline.children {
        if let newHash = h2.modified() {
          if let externalId = h2.properties[OrgPropertyKeys.externalId.rawValue] {
            print("Update item: \(externalId)")
          }
          h2.properties[OrgPropertyKeys.hash.rawValue] = newHash
          h2.properties[OrgPropertyKeys.lastModified.rawValue] = modifiedDate
          try updateHeadline(headline: h2)
        }
      }
    }
  }

  public init(filePath: String, orgSource: OrgSource) {
    self.filePath = filePath
    self.orgSource = orgSource
  }
}
