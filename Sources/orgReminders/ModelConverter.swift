import CommonLibrary
import EventKit
import Foundation
import OrgLibrary
import RemindersLibrary

public class ModelConverter {

  /// A description Convert OrgHeadline to CommonList
  /// - Parameter headline: OrgHeadline
  /// - Returns: CommonList
  func toCommonList(headline: OrgHeadline) -> CommonList {
    let commonList = CommonList(
      title: headline.title, id: headline.properties[OrgPropertyKeys.listId.rawValue])
    if headline.tags.contains("DELETED") {
      commonList.isDeleted = true
    }
    return commonList
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
    if let priority = headline.priority {
      commonReminder.priority = toRemindersPriority(orgPriority: priority)
    }
    if let status = headline.status {
      commonReminder.isCompleted = status == "DONE"
    }
    if let closed = headline.plans[OrgPlan.closed.rawValue] {
      commonReminder.completionDate = CommonDate(
        dateText: closed, format: OrgDateFormat.closed.rawValue)
    }
    if let scheduled = headline.plans[OrgPlan.scheduled.rawValue] {
      commonReminder.dueDate = CommonDate(
        dateText: scheduled, format: OrgDateFormat.scheduled.rawValue)
    }
    if let lastModified = headline.properties[OrgPropertyKeys.lastModified.rawValue] {
      commonReminder.lastModified = CommonDate(dateText: lastModified)
    }
    if let externalId = headline.properties[OrgPropertyKeys.externalId.rawValue] {
      commonReminder.externalId = externalId
    }
    if let notes = headline.content {
      commonReminder.notes = notes.trimmingBlank()
    }
    if headline.tags.contains("DELETED") {
      commonReminder.isDeleted = true
    }
    if let hash = headline.properties[OrgPropertyKeys.hash.rawValue] {
      commonReminder.hash = hash
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
    let commonReminder = CommonReminder(
      title: reminder.title, list: toCommonList(calendar: reminder.calendar))
    commonReminder.externalId = reminder.calendarItemExternalIdentifier
    commonReminder.priority = reminder.priority
    commonReminder.isCompleted = reminder.isCompleted
    commonReminder.isDeleted = false
    if let date = reminder.dueDateComponents?.date {
      commonReminder.dueDate = CommonDate(date: date, format: OrgDateFormat.scheduled.rawValue)
    }
    if let date = reminder.completionDate {
      commonReminder.completionDate = CommonDate(date: date, format: OrgDateFormat.closed.rawValue)
    }
    if let date = reminder.lastModifiedDate {
      commonReminder.lastModified = CommonDate(date: date)
    }
    commonReminder.notes = reminder.notes?.trimmingBlank()
    commonReminder.hash = commonReminder.computeHash()
    return commonReminder
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
      headline.properties[OrgPropertyKeys.lastModified.rawValue] = lastModified.dateText
    }
    if let dueDate = reminder.dueDate {
      headline.plans[OrgPlan.scheduled.rawValue] = dueDate.dateText
    }
    if let closed = reminder.completionDate {
      headline.plans[OrgPlan.closed.rawValue] = closed.dateText
    }
    if let notes = reminder.notes {
      headline.content = notes
    }
    headline.properties[OrgPropertyKeys.hash.rawValue] = reminder.hash
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

  func toRemindersPriority(priority: Int) -> Priority {
    switch priority {
    case 0:
      return Priority.none
    case 1:
      return Priority.low
    case 5:
      return Priority.medium
    case 9:
      return Priority.high
    default:
      return Priority.none
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
}
