import ArgumentParser
import Foundation
import RemindersLibrary
import SQLiteLibrary

enum SyncTarget {
    case sqlite(path: String)
    case json(path: String)
    case yaml(path: String)
}

func detectTarget(from path: String) -> SyncTarget {
    if path.hasSuffix(".json") { return .json(path: path) }
    if path.hasSuffix(".yaml") || path.hasSuffix(".yml") { return .yaml(path: path) }
    return .sqlite(path: path)
}

private struct Once: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Sync macOS Reminders to storage once (auto-detects format from extension)")

    @Argument(help: "Path to storage: .db for SQLite, .json for JSON, .yaml/.yml for YAML")
    var targetPath: String

    @Option(name: .shortAndLong, help: "Log level: 'info' or 'debug'")
    var logLevel: Synchronization.LogLevel = .info

    func run() throws {
        do {
            let sync: Synchronization
            switch detectTarget(from: targetPath) {
            case .sqlite(let path):
                sync = try Synchronization(databasePath: path, logLevel: self.logLevel)
            case .json(let path):
                let fileStorage = JSONFileStorage(filePath: path)
                sync = Synchronization(fileStorage: fileStorage, logLevel: self.logLevel)
            case .yaml(let path):
                let fileStorage = YAMLFileStorage(filePath: path)
                sync = Synchronization(fileStorage: fileStorage, logLevel: self.logLevel)
            }
            try sync.syncOnce()
            print("Sync completed successfully")
        } catch {
            throw CLIError.syncFailed(error.localizedDescription)
        }
    }
}

private struct Auto: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Automatically sync changes (auto-detects format from extension)")

    @Argument(help: "Path to storage: .db for SQLite, .json for JSON, .yaml/.yml for YAML")
    var targetPath: String

    @Option(name: .shortAndLong, help: "Log level: 'info' or 'debug'")
    var logLevel: Synchronization.LogLevel = .info

    func run() throws {
        do {
            let sync: Synchronization
            switch detectTarget(from: targetPath) {
            case .sqlite(let path):
                sync = try Synchronization(databasePath: path, logLevel: self.logLevel)
            case .json(let path):
                let fileStorage = JSONFileStorage(filePath: path)
                sync = Synchronization(fileStorage: fileStorage, logLevel: self.logLevel)
            case .yaml(let path):
                let fileStorage = YAMLFileStorage(filePath: path)
                sync = Synchronization(fileStorage: fileStorage, logLevel: self.logLevel)
            }
            try sync.syncAuto()
        } catch {
            throw CLIError.syncFailed(error.localizedDescription)
        }
    }
}

enum CLIError: LocalizedError {
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

public struct CLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "reminders-sync",
        abstract: "A CLI tool for syncing macOS Reminders with storage (SQLite, JSON, or YAML)",
        subcommands: [
            Once.self,
            Auto.self,
        ]
    )

    public init() {}
}