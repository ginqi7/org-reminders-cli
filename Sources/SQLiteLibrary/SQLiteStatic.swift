import SQLite

/// SQLite table and column definitions
public class SQLStatic {
    public static let remindersTable = Table("reminders")
    public static let listsTable = Table("lists")
    public static let syncTable = Table("sync")

    public static let idCol = SQLite.Expression<String>("id")
    public static let titleCol = SQLite.Expression<String>("title")
    public static let creationDateCol = SQLite.Expression<Int64>("creationDate")
    public static let lastModifiedCol = SQLite.Expression<Int64>("lastModified")
    public static let deletedCol = SQLite.Expression<Bool>("deleted")
    public static let dateCol = SQLite.Expression<Int64>("date")
    public static let externalIdCol = SQLite.Expression<String?>("externalId")
    public static let isCompletedCol = SQLite.Expression<Bool>("isCompleted")
    public static let priorityCol = SQLite.Expression<Int>("priority")
    public static let listIdCol = SQLite.Expression<String>("listId")
    public static let notesCol = SQLite.Expression<String?>("notes")
    public static let dueDateCol = SQLite.Expression<String?>("dueDate")
    public static let completionDateCol = SQLite.Expression<String?>("completionDate")
}
