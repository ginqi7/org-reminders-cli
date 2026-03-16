import CommonLibrary
import Foundation
import SQLite

public class SQLiteReminder {
    private let db: Connection

    public init(db: Connection) throws {
        self.db = db
        try initRemindersTable()
    }

    private func initRemindersTable() throws {
        try db.run(SQLStatic.remindersTable.create(ifNotExists: true) { table in
            table.column(SQLStatic.externalIdCol, unique: true)
            table.column(SQLStatic.titleCol)
            table.column(SQLStatic.isCompletedCol, defaultValue: false)
            table.column(SQLStatic.priorityCol, defaultValue: 0)
            table.column(SQLStatic.listIdCol)
            table.column(SQLStatic.notesCol)
            table.column(SQLStatic.dueDateCol)
            table.column(SQLStatic.completionDateCol)
            table.column(SQLStatic.lastModifiedCol)
            table.column(SQLStatic.deletedCol, defaultValue: false)
        })
    }

    public func add(reminder: CommonReminder) throws {
        guard let externalId = reminder.externalId, let listId = reminder.list.id else {
            return
        }

        let insert = SQLStatic.remindersTable.insert(or: .replace,
                                                     SQLStatic.externalIdCol <- externalId,
                                                     SQLStatic.titleCol <- reminder.title,
                                                     SQLStatic.isCompletedCol <- reminder.isCompleted,
                                                     SQLStatic.priorityCol <- reminder.priority,
                                                     SQLStatic.listIdCol <- listId,
                                                     SQLStatic.notesCol <- reminder.notes,
                                                     SQLStatic.dueDateCol <- reminder.dueDate?.dateText,
                                                     SQLStatic.completionDateCol <- reminder.completionDate?.dateText,
                                                     SQLStatic.lastModifiedCol <- SQLiteUtil.timeStamp(date: reminder.lastModified?.date ?? Date()),
                                                     SQLStatic.deletedCol <- false)

        try db.run(insert)
    }

    public func update(reminder: CommonReminder) throws {
        try add(reminder: reminder)
    }

    public func delete(externalId: String) throws {
        let reminder = SQLStatic.remindersTable.filter(SQLStatic.externalIdCol == externalId)
        try db.run(reminder.update(SQLStatic.deletedCol <- true))
    }

    public func getReminder(externalId: String) throws -> CommonReminder? {
        let reminder = SQLStatic.remindersTable.filter(SQLStatic.externalIdCol == externalId)
        guard let row = try db.pluck(reminder) else { return nil }
        return try rowToCommonReminder(row: row)
    }

    public func getReminders() throws -> [CommonReminder] {
        let query = SQLStatic.remindersTable.filter(SQLStatic.deletedCol == false)
        return try db.prepare(query).compactMap { try? rowToCommonReminder(row: $0) }
    }

    public func getReminders(listId: String) throws -> [CommonReminder] {
        let query = SQLStatic.remindersTable.filter(
            SQLStatic.listIdCol == listId && SQLStatic.deletedCol == false)
        return try db.prepare(query).compactMap { try? rowToCommonReminder(row: $0) }
    }

    private func rowToCommonReminder(row: Row) throws -> CommonReminder {
        let list = CommonList(title: row[SQLStatic.listIdCol], id: row[SQLStatic.listIdCol])
        let reminder = CommonReminder(
            title: row[SQLStatic.titleCol],
            list: list,
            externalId: row[SQLStatic.externalIdCol],
            priority: row[SQLStatic.priorityCol],
            isCompleted: row[SQLStatic.isCompletedCol],
            notes: row[SQLStatic.notesCol]
        )
        if let dueDateText = row[SQLStatic.dueDateCol] {
            reminder.dueDate = try? CommonDate(dateText: dueDateText)
        }
        if let completionDateText = row[SQLStatic.completionDateCol] {
            reminder.completionDate = try? CommonDate(dateText: completionDateText)
        }
        let lastModifiedMillis = row[SQLStatic.lastModifiedCol]
        let date = Date(timeIntervalSince1970: Double(lastModifiedMillis) / 1000)
        reminder.lastModified = CommonDate(date: date)
        return reminder
    }
}
