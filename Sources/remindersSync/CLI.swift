import ArgumentParser
import Foundation
import RemindersLibrary
import SQLiteLibrary

private struct Sync: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Sync macOS Reminders to SQLite database")

    @Option(name: .shortAndLong, help: "SQLite database path")
    var database: String = "~/reminders.db"

    @Option(name: .shortAndLong, help: "Sync type: 'all', 'auto', or 'once'")
    var type: Synchronization.SyncType = .once

    @Option(name: .shortAndLong, help: "Log level: 'info' or 'debug'")
    var logLevel: Synchronization.LogLevel = .info

    func run() throws {
        do {
            let sync = try Synchronization(
                databasePath: database,
                logLevel: self.logLevel
            )
            sync.sync(type: self.type)
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
        abstract: "A CLI tool for syncing macOS Reminders with SQLite database",
        subcommands: [
            Sync.self,
        ]
    )

    public init() {}
}
