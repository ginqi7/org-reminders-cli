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
    private var sqliteList: SQLiteList?
    private var sqliteReminder: SQLiteReminder?
    private var fileStorage: FileStorage?
    private var logger: SyncLogger
    private var eventStore: EKEventStore?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var databasePath: String
    private var filePath: String?

    public init(
        databasePath: String = "reminders.db",
        logLevel: LogLevel = .info
    ) throws {
        self.converter = ModelConverter()
        self.reminders = Reminders()
        self.logger = SyncLogger(level: logLevel)
        self.databasePath = NSString(string: databasePath).expandingTildeInPath

        self.sqliteList = try SQLiteList(databasePath: self.databasePath)
        self.sqliteReminder = try self.sqliteList!.createSQLiteReminder()
    }

    public init(fileStorage: FileStorage, logLevel: LogLevel = .info) {
        self.converter = ModelConverter()
        self.reminders = Reminders()
        self.logger = SyncLogger(level: logLevel)
        self.databasePath = ""
        self.fileStorage = fileStorage
        self.filePath = (fileStorage as? JSONFileStorage)?.filePath ?? (fileStorage as? YAMLFileStorage)?.filePath
    }

    deinit {
        if let eventStore = eventStore {
            NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: eventStore)
        }
        fileMonitorSource?.cancel()
    }

    public func syncOnce() throws {
        let (remindersLists, remindersItems) = fetchAllFromReminders()

        if let fileStorage = self.fileStorage {
            let fileData = try fileStorage.load()
            try syncListsWithFile(remindersLists: remindersLists, fileLists: fileData.lists)
            try syncRemindersWithFile(remindersItems: remindersItems, fileReminders: fileData.reminders, deletedFileReminders: [])
        } else {
            let sqliteLists = try self.sqliteList!.getLists()
            let sqliteReminders = try self.sqliteReminder!.getReminders()
            let deletedSqliteReminders = try self.sqliteReminder!.getDeletedReminders()

            try syncLists(remindersLists: remindersLists, sqliteLists: sqliteLists)
            try syncReminders(remindersItems: remindersItems, sqliteReminders: sqliteReminders, deletedSqliteReminders: deletedSqliteReminders)
        }
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

        if let filePath = self.filePath {
            monitorFileChanges(path: filePath)
        } else {
            monitorDatabaseFileChanges()
        }

        print("Auto sync enabled. Listening for changes from Reminders and \(self.filePath != nil ? "file" : "SQLite database")...")
        RunLoop.main.run()
    }

    private func monitorFileChanges(path: String) {
        let fileDescriptor = open(path, O_EVTONLY)

        guard fileDescriptor >= 0 else {
            print("Failed to open file descriptor for \(path)")
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
            self.performSync(source: "File")
            dispatchSource.resume()
        }

        dispatchSource.setCancelHandler {
            close(fileDescriptor)
        }

        dispatchSource.resume()
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
                    try self.sqliteList!.update(list: remindersList)
                    logAction(action: .update, value: remindersList)
                }
            } else {
                try self.sqliteList!.add(list: remindersList)
                logAction(action: .add, value: remindersList)
            }
        }

        for sqliteList in sqliteLists {
            guard let listId = sqliteList.id else { continue }
            if remindersDict[listId] == nil {
                try self.sqliteList!.delete(listId: listId)
                logAction(action: .delete, value: sqliteList)
            }
        }
    }

    private func syncListsWithFile(remindersLists: [CommonList], fileLists: [CommonList]) throws {
        guard let fileStorage = self.fileStorage else { return }

        var mergedLists = fileLists
        let remindersDict = Dictionary(uniqueKeysWithValues: remindersLists.map { ($0.id ?? "", $0) })
        let fileDict = Dictionary(uniqueKeysWithValues: fileLists.map { ($0.id ?? "", $0) })

        for remindersList in remindersLists {
            guard let listId = remindersList.id else { continue }

            if let fileList = fileDict[listId] {
                if remindersList.title != fileList.title {
                    if let index = mergedLists.firstIndex(where: { $0.id == listId }) {
                        mergedLists[index] = remindersList
                    }
                    logAction(action: .update, value: remindersList)
                }
            } else {
                mergedLists.append(remindersList)
                logAction(action: .add, value: remindersList)
            }
        }

        for fileList in fileLists {
            guard let listId = fileList.id else { continue }
            if remindersDict[listId] == nil {
                mergedLists.removeAll { $0.id == listId }
                logAction(action: .delete, value: fileList)
            }
        }

        let fileData = try fileStorage.load()
        try fileStorage.save(data: FileData(lists: mergedLists, reminders: fileData.reminders))
    }

    private func syncRemindersWithFile(remindersItems: [CommonReminder], fileReminders: [CommonReminder], deletedFileReminders: [CommonReminder]) throws {
        guard let fileStorage = self.fileStorage else { return }

        var mergedReminders = fileReminders
        let remindersDict = Dictionary(uniqueKeysWithValues: remindersItems.map { ($0.externalId ?? "", $0) })
        let fileDict = Dictionary(uniqueKeysWithValues: fileReminders.map { ($0.externalId ?? "", $0) })

        for reminder in remindersItems {
            guard let externalId = reminder.externalId else { continue }

            if let fileReminder = fileDict[externalId] {
                let updateDirection = try shouldUpdate(reminders: reminder, file: fileReminder)
                switch updateDirection {
                case .updateFile:
                    if let index = mergedReminders.firstIndex(where: { $0.externalId == externalId }) {
                        mergedReminders[index] = reminder
                    }
                    logAction(action: .update, value: reminder)
                case .updateReminders, .updateSQLite, .noUpdate:
                    break
                }
            } else {
                mergedReminders.append(reminder)
                logAction(action: .add, value: reminder)
            }
        }

        for fileReminder in fileReminders {
            guard let externalId = fileReminder.externalId else { continue }
            if remindersDict[externalId] == nil {
                mergedReminders.removeAll { $0.externalId == externalId }
                logAction(action: .delete, value: fileReminder)
            }
        }

        let fileData = try fileStorage.load()
        try fileStorage.save(data: FileData(lists: fileData.lists, reminders: mergedReminders))
    }

    private func syncReminders(remindersItems: [CommonReminder], sqliteReminders: [CommonReminder], deletedSqliteReminders: [CommonReminder]) throws {
        let remindersDict = Dictionary(uniqueKeysWithValues: remindersItems.map { ($0.externalId ?? "", $0) })
        let sqliteDict = Dictionary(uniqueKeysWithValues: sqliteReminders.map { ($0.externalId ?? "", $0) })

        for reminder in remindersItems {
            guard let externalId = reminder.externalId else { continue }

            if let sqliteReminder = sqliteDict[externalId] {
                let updateDirection = try shouldUpdate(reminders: reminder, sqlite: sqliteReminder)
                switch updateDirection {
                case .updateSQLite:
                    try self.sqliteReminder!.update(reminder: reminder)
                    logAction(action: .update, value: reminder)
                case .updateReminders, .updateFile, .noUpdate:
                    break
                }
            } else {
                try self.sqliteReminder!.add(reminder: reminder)
                logAction(action: .add, value: reminder)
            }
        }

        // Handle reminders that exist in SQLite but not in macOS Reminders
        for sqliteReminder in sqliteReminders {
            guard let externalId = sqliteReminder.externalId else { continue }
            if remindersDict[externalId] == nil {
                // Reminder was deleted from macOS Reminders, mark as deleted in SQLite
                try self.sqliteReminder!.delete(externalId: externalId)
                logAction(action: .delete, value: sqliteReminder)
            }
        }

        // Handle deletions from SQLite to macOS Reminders
        for sqliteReminder in deletedSqliteReminders {
            guard let externalId = sqliteReminder.externalId else { continue }

            // Remove from SQLite after successful deletion
            try self.sqliteReminder!.permanentlyDelete(externalId: externalId)

            logAction(action: .delete, value: sqliteReminder)
        }
    }

    private enum UpdateDirection {
        case noUpdate
        case updateSQLite
        case updateFile
        case updateReminders
    }

    private func shouldUpdate(reminders: CommonReminder, sqlite: CommonReminder) throws -> UpdateDirection {
        // Check if any fields differ
        let hasChanges = reminders.title != sqlite.title
            || reminders.isCompleted != sqlite.isCompleted
            || reminders.priority != sqlite.priority
            || reminders.notes != sqlite.notes
            || reminders.dueDate?.dateText != sqlite.dueDate?.dateText
            || reminders.completionDate?.dateText != sqlite.completionDate?.dateText

        guard hasChanges else {
            return .noUpdate
        }

        // Last-write-wins: compare lastModified timestamps
        let remindersTime = reminders.lastModified?.date ?? Date.distantPast
        let sqliteTime = sqlite.lastModified?.date ?? Date.distantPast

        logger.debug("Comparing timestamps for '\(reminders.title)':")
        logger.debug("  Reminders: \(remindersTime) (lastModified: \(reminders.lastModified?.dateText ?? "nil"))")
        logger.debug("  SQLite:    \(sqliteTime) (lastModified: \(sqlite.lastModified?.dateText ?? "nil"))")

        if sqliteTime > remindersTime {
            logger.debug("  -> Updating Reminders from SQLite (SQLite is newer)")
            return .updateReminders
        } else {
            logger.debug("  -> Updating SQLite from Reminders (Reminders is newer)")
            return .updateSQLite
        }
    }

    private func shouldUpdate(reminders: CommonReminder, file: CommonReminder) throws -> UpdateDirection {
        let hasChanges = reminders.title != file.title
            || reminders.isCompleted != file.isCompleted
            || reminders.priority != file.priority
            || reminders.notes != file.notes
            || reminders.dueDate?.dateText != file.dueDate?.dateText
            || reminders.completionDate?.dateText != file.completionDate?.dateText

        guard hasChanges else {
            return .noUpdate
        }

        let remindersTime = reminders.lastModified?.date ?? Date.distantPast
        let fileTime = file.lastModified?.date ?? Date.distantPast

        logger.debug("Comparing timestamps for '\(reminders.title)':")
        logger.debug("  Reminders: \(remindersTime) (lastModified: \(reminders.lastModified?.dateText ?? "nil"))")
        logger.debug("  File:      \(fileTime) (lastModified: \(file.lastModified?.dateText ?? "nil"))")

        if fileTime > remindersTime {
            logger.debug("  -> Updating Reminders from File (File is newer)")
            return .updateReminders
        } else {
            logger.debug("  -> Updating File from Reminders (Reminders is newer)")
            return .updateFile
        }
    }

    private func logAction<T: Encodable>(action: SyncLogger.Action, value: T) {
        self.logger.action = action
        self.logger.target = .sqlite
        self.logger.value = value
        self.logger.log()
    }
}
