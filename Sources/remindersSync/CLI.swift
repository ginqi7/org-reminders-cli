import ArgumentParser
import Foundation
import RemindersLibrary
import SQLiteLibrary

private struct Once: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Sync macOS Reminders to SQLite database once")

    @Option(name: .shortAndLong, help: "SQLite database path")
    var database: String = "~/reminders.db"

    @Option(name: .shortAndLong, help: "Log level: 'info' or 'debug'")
    var logLevel: Synchronization.LogLevel = .info

    func run() throws {
        do {
            let sync = try Synchronization(
                databasePath: database,
                logLevel: self.logLevel
            )
            try sync.syncOnce()
            print("Sync completed successfully")
        } catch {
            throw CLIError.syncFailed(error.localizedDescription)
        }
    }
}

private struct Auto: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Automatically sync changes between macOS Reminders and SQLite database")

    @Option(name: .shortAndLong, help: "SQLite database path")
    var database: String = "~/reminders.db"

    @Option(name: .shortAndLong, help: "Log level: 'info' or 'debug'")
    var logLevel: Synchronization.LogLevel = .info

    func run() throws {
        do {
            let sync = try Synchronization(
                databasePath: database,
                logLevel: self.logLevel
            )
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
        abstract: "A CLI tool for syncing macOS Reminders with SQLite database",
        subcommands: [
            Once.self,
            Auto.self,
        ]
    )

    public init() {}
}
