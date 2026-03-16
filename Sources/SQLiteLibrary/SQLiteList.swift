import CommonLibrary
import SQLite

public class SQLiteList {
    public let db: Connection

    public init(databasePath: String = "reminders.db") throws {
        self.db = try Connection(databasePath)
        try initListsTable()
    }

    private func initListsTable() throws {
        try db.run(SQLStatic.listsTable.create(ifNotExists: true) { table in
            table.column(SQLStatic.idCol, unique: true)
            table.column(SQLStatic.titleCol)
            table.column(SQLStatic.deletedCol, defaultValue: false)
        })
    }

    public func createSQLiteReminder() throws -> SQLiteReminder {
        return try SQLiteReminder(db: db)
    }

    public func add(list: CommonList) throws {
        guard let listId = list.id else { return }
        let insert = SQLStatic.listsTable.insert(or: .replace,
                                                 SQLStatic.idCol <- listId,
                                                 SQLStatic.titleCol <- list.title,
                                                 SQLStatic.deletedCol <- list.isDeleted)
        try db.run(insert)
    }

    public func update(list: CommonList) throws {
        try add(list: list)
    }

    public func delete(listId: String) throws {
        let list = SQLStatic.listsTable.filter(SQLStatic.idCol == listId)
        try db.run(list.update(SQLStatic.deletedCol <- true))
    }

    public func getList(listId: String) throws -> CommonList? {
        let list = SQLStatic.listsTable.filter(SQLStatic.idCol == listId)
        guard let row = try db.pluck(list) else { return nil }
        return rowToCommonList(row: row)
    }

    public func getLists() throws -> [CommonList] {
        let query = SQLStatic.listsTable.filter(SQLStatic.deletedCol == false)
        return try db.prepare(query).map { rowToCommonList(row: $0) }
    }

    private func rowToCommonList(row: Row) -> CommonList {
        return CommonList(
            title: row[SQLStatic.titleCol],
            id: row[SQLStatic.idCol]
        )
    }
}
