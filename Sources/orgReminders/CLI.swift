import ArgumentParser
import Foundation
import OrgLibrary
import RemindersLibrary

public enum SyncType: String, ExpressibleByArgument {
  case all, auto, once
}

public enum LogLevel: String, ExpressibleByArgument {
  case info, debug
}

private struct UpdateHash: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Update reminders hash in org file")

  @Argument(
    help: "Target file name")
  var fileName: String

  @Option(
    name: .shortAndLong,
    help: "Log Level, either of 'info' or 'debug'")
  var logLevel: LogLevel = .info

  func run() {
    do {
      let sync = try Synchronization(filePath: fileName, logLevel: self.logLevel, frequency: 1)
      let _ = try sync.updateHash()
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

  @Option(
    name: .shortAndLong,
    help: "Log Level, either of 'info' or 'debug'")
  var logLevel: LogLevel = .info

  @Option(
    name: .shortAndLong,
    help: "Sync frequency")
  var frequency: Int = 1

  @Option(
    name: .shortAndLong,
    help: "Display Options: all or incompleted or completed")
  var displayOptions: DisplayOptions = .all

  func run() {
    do {
      let sync = try Synchronization(
        filePath: fileName,
        logLevel: self.logLevel,
        frequency: self.frequency,
        displayOptions: self.displayOptions
      )
      sync.sync(type: self.type)
    } catch let error {
      print(error)
    }
  }
}

private struct WebsocketBridge: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "WebsocketBridge")

  @Argument(
    help: "appName")
  var appName: String

  @Argument(
    help: "serverPort")
  var serverPort: String

  func run() {
    do {
      let _ = try OrgRemindersBridge(appName: appName, serverPort: serverPort)
    } catch let error {
      print(error)
    }
  }
}

public struct CLI: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "org-reminders",
    abstract:
      "A CLI tool for syncing OS X Reminders with Emacs org-mode, designed to work with ginqi7/org-reminders.",
    subcommands: [
      UpdateHash.self,
      Sync.self,
      WebsocketBridge.self,
    ]
  )

  public init() {}
}
