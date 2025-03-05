import CommonLibrary
import EventKit
import Foundation
import OrgLibrary
import RemindersLibrary

public class ModelConverter {
  public var dateFormat = "yyyy-MM-dd HH:mm:ss"
  public var dateFormatter = DateFormatter()

  public init() {
    dateFormatter.dateFormat = dateFormat
  }

  private enum ConverterType: String {
    case org
    case reminder
  }

  /// A description Convert OrgHeadline to CommonList
  /// - Parameter headline: OrgHeadline
  /// - Returns: CommonList
  func toCommonList(headline: OrgHeadline) -> CommonList {
    return CommonList(
      title: headline.title, id: headline.properties[OrgPropertyKeys.listId.rawValue])
  }

  /// A description Convert OrgHeadline array to CommonList array
  /// - Parameter headlines: OrgHeadline array
  /// - Returns: CommonList array
  func toCommonLists(headlines: [OrgHeadline]) -> [CommonList] {
    return headlines.map { toCommonList(headline: $0) }
  }

  /// A description Convert OrgHeadline to CommandReminder
  /// - Parameter headline: OrgHeadline
  /// - Returns: CommonReminder
  func toCommonReminder(headline: OrgHeadline) -> CommonReminder {
    let commonReminder = CommonReminder(
      title: headline.title,
      list: toCommonList(headline: headline.parent!)
    )
    if let listName = headline.parent?.title {
      commonReminder.listName = listName
    }

    if let priority = headline.priority {
      commonReminder.priority = toRemindersPriority(orgPriority: priority)
    }
    if let status = headline.status {
      commonReminder.isCompleted = status == "DONE"
    }
    if let closed = headline.closed {
      commonReminder.completionDate = strToDate(str: closed)
    }
    if let scheduled = headline.scheduled {
      commonReminder.dueDate = strToDate(str: scheduled)
    }
    if let lastModified = headline.properties[OrgPropertyKeys.lastModified.rawValue] {
      commonReminder.lastModified = strToDate(str: lastModified)
    }
    if let externalId = headline.properties[OrgPropertyKeys.externalId.rawValue] {
      commonReminder.externalId = externalId
    }
    return commonReminder
  }

  /// A description Convert OrgHeadline array to CommonReminder array.
  /// - Parameter headlines: OrgHeadline array
  /// - Returns: CommonReminder array
  func toCommonReminders(headlines: [OrgHeadline]) -> [CommonReminder] {
    var commonReminders: [CommonReminder] = []
    for headline in headlines {
      for children in headline.children {
        commonReminders.append(toCommonReminder(headline: children))
      }
    }
    return commonReminders
  }

  /// A description Convert EKCalendar to CommonList
  /// - Parameter calendar: EKCalendar
  /// - Returns: CommonList
  func toCommonList(calendar: EKCalendar) -> CommonList {
    return CommonList(title: calendar.title, id: calendar.calendarIdentifier)
  }

  /// A description Convert EKCalendar array to CommonList array
  /// - Parameter calendars: EKCalendar array
  /// - Returns: CommonList array
  func toCommonLists(calendars: [EKCalendar]) -> [CommonList] {
    return calendars.map { toCommonList(calendar: $0) }
  }

  /// A description Convert EKReminder array to CommonReminder array
  /// - Parameter reminders: EKReminder array
  /// - Returns: CommonReminder array
  func toCommonReminders(reminders: [EKReminder]) -> [CommonReminder] {
    return reminders.map { return toCommonReminder(reminder: $0) }
  }

  /// A description Convert EKReminder to CommonReminder
  /// - Parameter reminder: EKReminder
  /// - Returns: CommonReminder
  func toCommonReminder(reminder: EKReminder) -> CommonReminder {
    let orgReminder = CommonReminder(
      title: reminder.title, list: toCommonList(calendar: reminder.calendar))
    orgReminder.externalId = reminder.calendarItemExternalIdentifier
    orgReminder.priority = reminder.priority
    orgReminder.isCompleted = reminder.isCompleted
    orgReminder.isDeleted = false
    orgReminder.dueDate = reduceTimePrecision(from: reminder.dueDateComponents?.date)
    orgReminder.completionDate = reduceTimePrecision(from: reminder.completionDate)
    orgReminder.lastModified = reduceTimePrecision(from: reminder.lastModifiedDate)
    orgReminder.listName = reminder.calendar.title
    orgReminder.listId = reminder.calendar.calendarIdentifier
    orgReminder.notes = reminder.notes
    return orgReminder
  }

  /// A description Convert CommonList and CommonReminder array to OrgHeadline
  /// - Parameters:
  ///   - list: CommonList
  ///   - reminders: CommonReminder array
  ///
  /// - Returns: OrgHeadline
  func toOrgHeadline(list: CommonList, reminders: [CommonReminder]) -> OrgHeadline {
    let headline = toOrgHeadline(list: list)
    headline.children = reminders.map { toOrgHeadline(reminder: $0) }
    return headline
  }

  /// A description Convert CommonList array and CommonReminder array to OrgHeadline array
  /// - Parameters:
  ///   - lists: CommonList array
  ///   - reminders: CommonReminder array
  ///
  /// - Returns: OrgHeadline array
  func toOrgHeadlines(lists: [CommonList], reminders: [CommonReminder]) -> [OrgHeadline] {
    var groupedByList = reminders.reduce(into: [CommonList: [CommonReminder]]()) {
      result, reminder in
      result[reminder.list, default: []].append(reminder)
    }
    for list in lists {
      if groupedByList[list] == nil {
        groupedByList[list] = []
      }
    }
    return groupedByList.map { toOrgHeadline(list: $0.key, reminders: $0.value) }
  }

  /// A description Convert CommonList to OrgHeadline
  /// - Parameter list: CommonList
  /// - Returns: OrgHeadline
  func toOrgHeadline(list: CommonList) -> OrgHeadline {
    let headline = OrgHeadline()
    headline.title = list.title
    if let id = list.id {
      headline.properties[OrgPropertyKeys.listId.rawValue] = id
    }
    return headline
  }

  /// A description Convert CommonReminder to OrgHeadline
  /// - Parameter reminder: CommonReminder
  /// - Returns: OrgHeadline
  func toOrgHeadline(reminder: CommonReminder) -> OrgHeadline {
    let parent = toOrgHeadline(list: reminder.list)
    let headline = OrgHeadline()
    headline.parent = parent
    headline.level = 2
    headline.title = reminder.title
    headline.priority = toOrgPriority(reminderPriority: reminder.priority)
    headline.status = reminder.isCompleted ? "DONE" : "TODO"

    if let id = reminder.externalId {
      headline.properties[OrgPropertyKeys.externalId.rawValue] = id
    }
    if let lastModified = reminder.lastModified {
      headline.properties[OrgPropertyKeys.lastModified.rawValue] = dateToStr(
        date: lastModified)
    }
    if let dueDate = reminder.dueDate {
      headline.scheduled = dateToStr(date: dueDate)
    }
    if let closed = reminder.completionDate {
      headline.closed = dateToStr(date: closed)
    }
    if let notes = reminder.notes {
      headline.content = notes
    }
    let hash = headline.computeHash()
    headline.properties[OrgPropertyKeys.hash.rawValue] = hash
    return headline
  }

  /// A description Convert org Priority to Reminders Priority
  /// - Parameter orgPriority: String?
  /// - Returns: Int
  func toRemindersPriority(orgPriority: String?) -> Int {
    if let priority = orgPriority {
      switch priority {
      case "A":
        return 1
      case "B":
        return 5
      case "C":
        return 9
      default:
        return 0
      }
    } else {
      return 0
    }
  }

  /// A description Convert Reminders Priority to org Priority
  /// - Parameter reminderPriority: Int
  /// - Returns: String?
  func toOrgPriority(reminderPriority: Int) -> String? {
    switch reminderPriority {
    case 1:
      return "A"
    case 5:
      return "B"
    case 9:
      return "C"
    default:
      return nil
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

  /// A description Convert date string to Date object
  /// - Parameter str: date string
  /// - Returns: Date?
  public func strToDate(str: String) -> Date? {
    return self.dateFormatter.date(from: str)
  }

  /// A description Convert date to format string
  /// - Parameter date: Data?
  /// - Returns: String

  public func dateToStr(date: Date?) -> String? {
    guard let date = date else {
      return nil
    }
    return self.dateFormatter.string(from: date)
  }

}
