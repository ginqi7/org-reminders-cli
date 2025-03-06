import Foundation

public class CommonDate {
  var _date: Date
  var _dateText: String
  public var dateText: String {
    return _dateText
  }
  public var date: Date {
    return _date
  }

  var format: String = "yyyy-MM-dd HH:mm:ss"
  var dateFormatter = DateFormatter()

  public init(date: Date = Date(), format: String = "yyyy-MM-dd HH:mm:ss") {
    self.format = format
    dateFormatter.dateFormat = format
    dateFormatter.locale = Locale(identifier: "en_US")
    self._dateText = self.dateFormatter.string(from: date)
    /// Reduce Time Precision, don't need microsecond
    self._date = self.dateFormatter.date(from: _dateText)!
  }

  public init(dateText: String, format: String = "yyyy-MM-dd HH:mm:ss") {
    self.format = format
    self._dateText = dateText
    dateFormatter.dateFormat = format
    dateFormatter.locale = Locale(identifier: "en_US")
    if let _date = self.dateFormatter.date(from: dateText) {
      self._date = _date
    } else {
      print("Error: DateFormatUnmatched: \(dateText) (\(format))")
      self._date = Date()
    }

  }

  /// A description Reduce Time Precision, don't need microsecond
  /// - Parameter date: Date?
  /// - Returns:
  func reduceTimePrecision(from date: Date?) -> Date? {
    guard let date = date else {
      return nil
    }

    let calendar = Calendar.current
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: date)
    return calendar.date(from: components)
  }

  public func toDateComponents() -> DateComponents {
    let calendar = Calendar.current
    return calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: self.date)
  }
}
