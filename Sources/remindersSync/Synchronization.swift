import ArgumentParser
import CommonLibrary
import Dispatch
import EventKit
import Foundation
import RemindersLibrary
import SQLiteLibrary

public class Synchronization {
    public enum LogLevel: String, ExpressibleByArgument {
        case info, debug
    }

    private var converter: ModelConverter
    private var reminders: Reminders
    private var sqliteList: SQLiteList
    private var sqliteReminder: SQLiteReminder
    private var logger: SyncLogger
    private var eventStore: EKEventStore?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var databasePath: String

    public init(
        databasePath: String = "reminders.db",
        logLevel: LogLevel = .info
    ) throws {
        self.converter = ModelConverter()
        self.reminders = Reminders()
        self.logger = SyncLogger(level: logLevel)
        self.databasePath = NSString(string: databasePath).expandingTildeInPath

        self.sqliteList = try SQLiteList(databasePath: self.databasePath)
        self.sqliteReminder = try self.sqliteList.createSQLiteReminder()
    }

    deinit {
        if let eventStore = eventStore {
            NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: eventStore)
        }
        fileMonitorSource?.cancel()
    }

    public func syncOnce() throws {
        let (remindersLists, remindersItems) = fetchAllFromReminders()

        let sqliteLists = try self.sqliteList.getLists()
        let sqliteReminders = try self.sqliteReminder.getReminders()

        try syncLists(remindersLists: remindersLists, sqliteLists: sqliteLists)
        try syncReminders(remindersItems: remindersItems, sqliteReminders: sqliteReminders)
    }

    public func syncAuto() throws {
        // Listen for macOS Reminders changes
        eventStore = EKEventStore()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemindersChange),
            name: .EKEventStoreChanged,
            object: eventStore
        )

        // Listen for SQLite database file changes
        monitorDatabaseFileChanges()

        print("Auto sync enabled. Listening for changes from Reminders and SQLite database...")
        RunLoop.main.run()
    }

    @objc private func handleRemindersChange() {
        performSync(source: "Reminders")
    }

    private func performSync(source: String) {
        do {
            try syncOnce()
            print("Sync completed (triggered by: \(source))")
        } catch {
            print("Sync error: \(error)")
        }
    }

    private func monitorDatabaseFileChanges() {
        let fileDescriptor = open(databasePath, O_EVTONLY)

        guard fileDescriptor >= 0 else {
            print("Failed to open file descriptor for \(databasePath)")
            return
        }

        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )

        self.fileMonitorSource = dispatchSource

        dispatchSource.setEventHandler { [weak self] in
            guard let self = self else { return }
            dispatchSource.suspend()
            self.performSync(source: "SQLite")
            dispatchSource.resume()
        }

        dispatchSource.setCancelHandler {
            close(fileDescriptor)
        }

        dispatchSource.resume()
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
                    logAction(action: .update, value: remindersList)
                }
            } else {
                try self.sqliteList.add(list: remindersList)
                logAction(action: .add, value: remindersList)
            }
        }

        for sqliteList in sqliteLists {
            guard let listId = sqliteList.id else { continue }
            if remindersDict[listId] == nil {
                try self.sqliteList.delete(listId: listId)
                logAction(action: .delete, value: sqliteList)
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
                    logAction(action: .update, value: reminder)
                }
            } else {
                try self.sqliteReminder.add(reminder: reminder)
                logAction(action: .add, value: reminder)
            }
        }

        for sqliteReminder in sqliteReminders {
            guard let externalId = sqliteReminder.externalId else { continue }
            if remindersDict[externalId] == nil {
                try self.sqliteReminder.delete(externalId: externalId)
                logAction(action: .delete, value: sqliteReminder)
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

    private func logAction<T: Encodable>(action: SyncLogger.Action, value: T) {
        self.logger.action = action
        self.logger.target = .sqlite
        self.logger.value = value
        self.logger.log()
    }
}
