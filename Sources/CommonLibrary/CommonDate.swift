import Foundation

public class CommonDate {
    private var _date: Date
    private var _dateText: String

    private let format: String
    private let dateFormatter: DateFormatter

    public var dateText: String {
        return _dateText
    }

    public var date: Date {
        return _date
    }

    public init(date: Date = Date(), format: String = "yyyy-MM-dd HH:mm:ss") {
        self.format = format
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = format
        self.dateFormatter.locale = Locale(identifier: "en_US")
        self._dateText = self.dateFormatter.string(from: date)
        // Reduce Time Precision, don't need microsecond
        self._date = self.dateFormatter.date(from: _dateText) ?? date
    }

    public init(dateText: String, format: String = "yyyy-MM-dd HH:mm:ss") throws {
        self.format = format
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = format
        self.dateFormatter.locale = Locale(identifier: "en_US")

        if let parsedDate = self.dateFormatter.date(from: dateText) {
            self._date = parsedDate
            self._dateText = dateText
        } else {
            throw RemindersSyncError.dateParseError(dateText: dateText, format: format)
        }
    }

    public func toDateComponents() -> DateComponents {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: self.date)
    }
}
