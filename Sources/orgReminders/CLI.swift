import ArgumentParser
import Foundation
import OrgLibrary

public enum SyncType: String, ExpressibleByArgument {
  case all, auto, once
}

private struct UpdateHash: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Update reminders hash in org file")

  @Argument(
    help: "Target file name")
  var fileName: String

  func run() {
    do {
      let sync = try Synchronization(filePath: fileName)
      try sync.updateHash()
    } catch let error {
      print(error)
    }
  }
}

private struct Sync: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Sync to file")

  @Argument(
    help: "Target file name")
  var fileName: String

  @Option(
    name: .shortAndLong,
    help: "format, either of 'all' or 'auto' or 'once'")
  var type: SyncType = .once

  func run() {
    do {
      let sync = try Synchronization(filePath: fileName)
      sync.sync(type: self.type)
    } catch let error {
      print(error)
    }
  }
}

public struct CLI: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Interact with macOS Reminders from the command line",
    subcommands: [
      UpdateHash.self,
      Sync.self,
    ]
  )

  public init() {}
}
