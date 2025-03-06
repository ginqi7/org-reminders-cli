import Foundation

public class OrgDate {
  var date: Date
  var format: String = OrgDateFormat.other.rawValue
  var dateText: String
  var dateFormatter = DateFormatter()

  public init(date: Date, format: String = OrgDateFormat.other.rawValue) {
    self.format = format
    self.date = date
    dateFormatter.dateFormat = format
    self.dateText = self.dateFormatter.string(from: date)
  }

  public init(dateText: String, format: String = OrgDateFormat.other.rawValue) {
    self.format = format
    self.dateText = dateText
    dateFormatter.dateFormat = format
    self.date = self.dateFormatter.date(from: dateText)!
  }

}
