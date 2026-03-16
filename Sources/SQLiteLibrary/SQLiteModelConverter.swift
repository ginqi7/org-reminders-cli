import CommonLibrary
import EventKit
import Foundation

public class ModelConverter {
    public init() {}

    // MARK: - EKCalendar to CommonList

    public func toCommonList(calendar: EKCalendar) -> CommonList {
        return CommonList(title: calendar.title, id: calendar.calendarIdentifier)
    }

    public func toCommonLists(calendars: [EKCalendar]) -> [CommonList] {
        return calendars.map { toCommonList(calendar: $0) }
    }

    // MARK: - EKReminder to CommonReminder

    public func toCommonReminders(reminders: [EKReminder]) -> [CommonReminder] {
        return reminders.map { toCommonReminder(reminder: $0) }
    }

    public func toCommonReminder(reminder: EKReminder) -> CommonReminder {
        let commonReminder = CommonReminder(
            title: reminder.title, list: toCommonList(calendar: reminder.calendar))
        commonReminder.externalId = reminder.calendarItemExternalIdentifier
        commonReminder.priority = reminder.priority
        commonReminder.isCompleted = reminder.isCompleted
        commonReminder.isDeleted = false
        if let date = reminder.dueDateComponents?.date {
            commonReminder.dueDate = CommonDate(date: date)
        }
        if let date = reminder.completionDate {
            commonReminder.completionDate = CommonDate(date: date)
        }
        if let date = reminder.lastModifiedDate {
            commonReminder.lastModified = CommonDate(date: date)
        }
        commonReminder.notes = reminder.notes?.trimmingBlank()
        commonReminder.hash = commonReminder.computeHash()
        return commonReminder
    }

    // MARK: - Date Helpers

    public func dateToDateComponents(date: Date?) -> DateComponents? {
        guard let date = date else {
            return nil
        }
        let calendar = Calendar.current
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
}
