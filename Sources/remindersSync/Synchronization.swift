import ArgumentParser
import CommonLibrary
import Dispatch
import EventKit
import Foundation
import RemindersLibrary
import SQLiteLibrary

public class Synchronization {
    public enum SyncType: String, ExpressibleByArgument {
        case all, auto, once
    }

    public enum LogLevel: String, ExpressibleByArgument {
        case info, debug
    }

    private var converter: ModelConverter
    private var reminders: Reminders
    private var sqliteList: SQLiteList
    private var sqliteReminder: SQLiteReminder
    private var logger: SyncLogger
    private var eventStore: EKEventStore?

    public init(
        databasePath: String = "reminders.db",
        logLevel: LogLevel = .info
    ) throws {
        self.converter = ModelConverter()
        self.reminders = Reminders()
        self.logger = SyncLogger(level: logLevel)

        let expandedPath = NSString(string: databasePath).expandingTildeInPath
        self.sqliteList = try SQLiteList(databasePath: expandedPath)
        self.sqliteReminder = try self.sqliteList.createSQLiteReminder()
    }

    deinit {
        if let eventStore = eventStore {
            NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: eventStore)
        }
    }

    public func sync(type: SyncType) {
        do {
            switch type {
            case .auto:
                try self.syncAuto()
            case .all:
                try self.syncAll()
            default:
                try self.syncOnce()
            }
        } catch {
            print("Failed to sync reminders with error: \(error)")
            exit(1)
        }
    }

    @objc private func handleRemindersChange() {
        do {
            try syncOnce()
            print("Sync completed due to Reminders change")
        } catch {
            print("Sync error: \(error)")
        }
    }

    public func syncAuto() throws {
        eventStore = EKEventStore()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemindersChange),
            name: .EKEventStoreChanged,
            object: eventStore
        )
        print("Auto sync enabled. Listening for Reminders changes...")
        RunLoop.main.run()
    }

    public func syncOnce() throws {
        let (remindersLists, remindersItems) = fetchAllFromReminders()

        let sqliteLists = try self.sqliteList.getLists()
        let sqliteReminders = try self.sqliteReminder.getReminders()

        try syncLists(remindersLists: remindersLists, sqliteLists: sqliteLists)
        try syncReminders(remindersItems: remindersItems, sqliteReminders: sqliteReminders)
    }

    public func syncAll() throws {
        let (remindersLists, remindersItems) = fetchAllFromReminders()

        for list in remindersLists {
            try self.sqliteList.add(list: list)
            print("Synced list to SQLite: \(list.title)")
        }

        for reminder in remindersItems {
            try self.sqliteReminder.add(reminder: reminder)
            print("Synced reminder to SQLite: \(reminder.title)")
        }

        print("Sync all completed. \(remindersLists.count) lists and \(remindersItems.count) reminders saved.")
    }

    private func fetchAllFromReminders() -> ([CommonList], [CommonReminder]) {
        let remindersLists = self.converter.toCommonLists(calendars: self.reminders.getLists())
        let remindersItems = self.converter.toCommonReminders(
            reminders: self.reminders.allReminders(displayOptions: .all))
        return (remindersLists, remindersItems)
    }

    private func syncLists(remindersLists: [CommonList], sqliteLists: [CommonList]) throws {
        let remindersDict = Dictionary(uniqueKeysWithValues: remindersLists.map { ($0.id ?? "", $0) })
        let sqliteDict = Dictionary(uniqueKeysWithValues: sqliteLists.map { ($0.id ?? "", $0) })

        for remindersList in remindersLists {
            guard let listId = remindersList.id else { continue }

            if let sqliteList = sqliteDict[listId] {
                if remindersList.title != sqliteList.title {
                    try self.sqliteList.update(list: remindersList)
                    logAction(action: .update, value: remindersList, target: .sqlite)
                }
            } else {
                try self.sqliteList.add(list: remindersList)
                logAction(action: .add, value: remindersList, target: .sqlite)
            }
        }

        for sqliteList in sqliteLists {
            guard let listId = sqliteList.id else { continue }
            if remindersDict[listId] == nil {
                try self.sqliteList.delete(listId: listId)
                logAction(action: .delete, value: sqliteList, target: .sqlite)
            }
        }
    }

    private func syncReminders(remindersItems: [CommonReminder], sqliteReminders: [CommonReminder]) throws {
        let remindersDict = Dictionary(uniqueKeysWithValues: remindersItems.map { ($0.externalId ?? "", $0) })
        let sqliteDict = Dictionary(uniqueKeysWithValues: sqliteReminders.map { ($0.externalId ?? "", $0) })

        for reminder in remindersItems {
            guard let externalId = reminder.externalId else { continue }

            if let sqliteReminder = sqliteDict[externalId] {
                if try shouldUpdateReminder(reminders: reminder, sqlite: sqliteReminder) {
                    try self.sqliteReminder.update(reminder: reminder)
                    logAction(action: .update, value: reminder, target: .sqlite)
                }
            } else {
                try self.sqliteReminder.add(reminder: reminder)
                logAction(action: .add, value: reminder, target: .sqlite)
            }
        }

        for sqliteReminder in sqliteReminders {
            guard let externalId = sqliteReminder.externalId else { continue }
            if remindersDict[externalId] == nil {
                try self.sqliteReminder.delete(externalId: externalId)
                logAction(action: .delete, value: sqliteReminder, target: .sqlite)
            }
        }
    }

    private func shouldUpdateReminder(reminders: CommonReminder, sqlite: CommonReminder) throws -> Bool {
        if reminders.title != sqlite.title { return true }
        if reminders.isCompleted != sqlite.isCompleted { return true }
        if reminders.priority != sqlite.priority { return true }
        if reminders.notes != sqlite.notes { return true }
        if reminders.dueDate?.dateText != sqlite.dueDate?.dateText { return true }
        if reminders.completionDate?.dateText != sqlite.completionDate?.dateText { return true }
        return false
    }

    private func logAction<T: Encodable>(action: SyncLogger.Action, value: T, target: SyncLogger.Target) {
        self.logger.action = action
        self.logger.target = target
        self.logger.value = value
        self.logger.log()
    }
}
