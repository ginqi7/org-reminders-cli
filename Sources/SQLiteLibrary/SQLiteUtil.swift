import Foundation

/// SQLite timestamp utility
public class SQLiteUtil {
    /// Convert Date to milliseconds since epoch
    public static func timeStamp(date: Date? = nil) -> Int64 {
        let time = date ?? Date()
        let timeStampMillis = time.timeIntervalSince1970 * 1000
        return Int64(timeStampMillis)
    }
}
