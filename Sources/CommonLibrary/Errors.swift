import Foundation

public enum RemindersSyncError: LocalizedError {
    case fileReadError(path: String)
    case fileWriteError(path: String)
    case parseError(description: String)
    case dateParseError(dateText: String, format: String)
    case encodingError(description: String)
    case invalidData(description: String)
    case databaseError(description: String)
    case remindersAccessDenied
    case synchronizationFailed(description: String)

    public var errorDescription: String? {
        switch self {
        case .fileReadError(let path):
            return "Failed to read file at path: \(path)"
        case .fileWriteError(let path):
            return "Failed to write file at path: \(path)"
        case .parseError(let description):
            return "Parse error: \(description)"
        case .dateParseError(let dateText, let format):
            return "Failed to parse date '\(dateText)' with format '\(format)'"
        case .encodingError(let description):
            return "Encoding error: \(description)"
        case .invalidData(let description):
            return "Invalid data: \(description)"
        case .databaseError(let description):
            return "Database error: \(description)"
        case .remindersAccessDenied:
            return "Access to Reminders is denied"
        case .synchronizationFailed(let description):
            return "Synchronization failed: \(description)"
        }
    }
}
