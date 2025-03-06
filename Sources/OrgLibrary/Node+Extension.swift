import Foundation
import SwiftTreeSitter
import TreeSitterOrg

extension Node {

  /// A description Find child when the type equal `type`
  /// - Parameters:
  ///   - node: Node
  ///   - type: String
  ///
  /// - Returns: Node?
  public func findChildUntil(type: OrgTreeSitterType) -> Node? {
    return (0..<self.namedChildCount)
      .compactMap { self.namedChild(at: $0) }
      .first { $0.nodeType == type.rawValue }
  }

  public func findChildren(type: OrgTreeSitterType) -> [Node] {
    var chidren: [Node] = []
    for i in 0...self.namedChildCount {
      if let child = self.namedChild(at: i) {
        if child.nodeType == OrgTreeSitterType.section.rawValue {
          chidren.append(child)
        }
      }
    }
    return chidren
  }

  /// A description Get Node text.
  /// - Parameter node: Node
  /// - Returns: String
  public func getText(source: String) -> String {
    guard let range = getStringIndexRange(source: source) else { return "" }
    return String(source[range])
  }

  /// A description get Node Range
  /// - Parameter node: Node
  /// - Returns: Range<String.Index>?
  public func getStringIndexRange(source: String) -> Range<String.Index>? {
    return Range(self.range, in: source)
  }

  public func getLowerBoundIndex(source: String) -> String.Index? {
    return getStringIndexRange(source: source)?.lowerBound
  }

  public func getUpperBoundIndex(source: String) -> String.Index? {
    return getStringIndexRange(source: source)?.upperBound
  }

}
