import CommonLibrary
import Dispatch
import Foundation
import OrgLibrary
import RemindersLibrary

public class Synchronization {
  var filePath: String
  var converter: ModelConverter
  var orgSource: OrgSource
  var reminders: Reminders
  var logger: SyncLogger

  init(filePath: String, logLevel: LogLevel) throws {
    self.filePath = filePath
    self.orgSource = try OrgSource(filePath: filePath)
    self.converter = ModelConverter()
    self.reminders = Reminders()
    self.logger = SyncLogger(level: logLevel)
  }

  func sync(type: SyncType) {
    do {
      switch type {
      case .auto:
        try self.syncAuto()
      case .all:
        try self.syncAll()
      default:
        try self.syncOnce()
      }

    } catch let error {
      print("Failed to sync reminders with error: \(error)")
      exit(1)
    }
  }

  func updateHash() throws {
    try self.orgSource.refreshSource()
    try self.orgSource.refreshOrgHeadlines()
    let items = self.orgSource.getAllH2s().map {
      self.converter.toCommonReminder(headline: $0)
    }
    deleteRepeatedItem(items: items)
    for item in items {
      if let hash = item.modified() {
        item.hash = hash
        item.lastModified = CommonDate()
        actionToOrg(action: .update, value: item)
      }
    }
  }

  func deleteRepeatedItem(items: [CommonReminder]) {
    let groupedDictionary = Dictionary(
      grouping: items.filter({ $0.externalId != nil }),
      by: { $0.externalId })
    let duplicates = groupedDictionary.filter { $0.value.count > 1 }
    duplicates.values
      .forEach { actionToOrg(action: .delete, value: $0.first!) }
  }

  func syncAuto() throws {
    startPolling()
    monitorFileChanges()
  }

  func syncOnce() throws {
    // Get Data from Reminders
    let (remindersLists, remindersItems) = fetchAllFromReminders()

    // Get Data from Org Mode.
    try self.orgSource.refreshOrgHeadlines()
    let headlines = self.orgSource.getHeadlines()
    let orgLists = self.converter.toCommonLists(headlines: headlines)
    let orgTodos = self.converter.toCommonReminders(headlines: headlines)
    // Sync Data.
    // print(headlines.count)
    // print(orgLists.count)
    // print(headlines.map({ $0.properties["LIST-ID"] }))
    try syncLists(orgLists: orgLists, remindersLists: remindersLists)
    try syncItems(orgItems: orgTodos, remindersItems: remindersItems)
  }

  public func measureTime(name: String, block: () throws -> Void) throws {
    let start = Date()
    try block()
    let end = Date()
    print("[\(name)]方法调用时间：\(end.timeIntervalSince(start)) 秒")
  }

  func fetchAllFromReminders() -> ([CommonList], [CommonReminder]) {
    let remindersLists = self.converter.toCommonLists(calendars: self.reminders.getLists())
    let remindersItems = self.converter.toCommonReminders(
      reminders: self.reminders.allReminders(displayOptions: .all))
    return (remindersLists, remindersItems)
  }

  func syncAll() throws {
    // Get Data from Reminders.
    let (remindersLists, remindersItems) = fetchAllFromReminders()

    // Flush all headlines to Org Mode file.
    let headlines = self.converter.toOrgHeadlines(lists: remindersLists, reminders: remindersItems)
    try self.orgSource.flushHeadlines(headlines: headlines)

  }

  func arrayToDictionary<T>(from items: [T], keyProvider: (T) -> String?) -> [String?: T] {
    return
      items.filter { keyProvider($0) != nil }
      .reduce(into: [String: T]()) { result, item in
        result[keyProvider(item)!] = item
      }
  }

  func syncItems(orgItems: [CommonReminder], remindersItems: [CommonReminder]) throws {
    let orgDictionary = arrayToDictionary(from: orgItems, keyProvider: { $0.externalId })
    // print(orgDictionary)
    let remindersDictionary = arrayToDictionary(
      from: remindersItems, keyProvider: { $0.externalId })

    for orgItem in orgItems {
      // There is no externalId, It is a new item in Org Mode file.
      guard let externalId = orgItem.externalId else {
        if let reminder = try addItemToReminders(item: orgItem) {
          // print(reminder.toJson())
          actionToOrg(action: .update, value: reminder)
        }
        continue
      }
      // There is no matched item in Reminders, So It's deleted in Reminders.
      guard let matchedItem = remindersDictionary[externalId] else {
        actionToOrg(action: .delete, value: orgItem)
        continue
      }
      // Sync Item.
      try syncItem(orgItem: orgItem, remindersItem: matchedItem)
    }

    // There is no matched item in OrgMode, It a new Item in Reminders.
    for remindersItem in remindersItems {
      if orgDictionary[remindersItem.externalId] == nil {
        actionToOrg(action: .add, value: remindersItem)
      }
    }
  }

  func syncLists(orgLists: [CommonList], remindersLists: [CommonList]) throws {
    let orgDictionary = arrayToDictionary(from: orgLists) { $0.id }
    let remindersDictionary = arrayToDictionary(from: remindersLists) { $0.id }

    for orgList in orgLists {
      // There is no id, It is a new list in Org Mode file.
      guard let orgListId = orgList.id else {
        try addListToReminders(list: orgList)
        continue
      }
      // There is no matched list in Reminders, So It's deleted in Reminders.
      guard let matchedList = remindersDictionary[orgListId] else {
        actionToOrg(action: .delete, value: orgList)
        continue
      }
      // Sync List.
      syncList(orgList: orgList, remindersList: matchedList)
    }
    // There is no matched list in OrgMode, It a new list in Reminders.
    for remindersList in remindersLists {
      if orgDictionary[remindersList.id] == nil {
        actionToOrg(action: .add, value: remindersList)
      }
    }
  }

  func syncList(orgList: CommonList, remindersList: CommonList) {
    if orgList.title != remindersList.title {
      actionToOrg(action: .update, value: remindersList)
    }
  }

  func syncItem(orgItem: CommonReminder, remindersItem: CommonReminder) throws {
    guard
      let orgLastModified = orgItem.lastModified,
      let remindersLastModified = remindersItem.lastModified
    else {
      return
    }
    if orgItem.isDeleted {
      actionToReminders(action: .delete, value: orgItem)
      let _ = try self.reminders.delete(query: orgItem.externalId!, listQuery: orgItem.list.id!)
      return
    }
    if orgLastModified.date == remindersLastModified.date {
      return
    }
    var updateReminder = remindersItem
    if orgLastModified.date > remindersLastModified.date {
      actionToReminders(action: .update, value: orgItem)
      if let reminder = try reminders.updateItem(
        query: orgItem.externalId!,
        listQuery: orgItem.list.id!,
        newText: orgItem.title,
        newNotes: orgItem.notes,
        url: nil,
        isCompleted: orgItem.isCompleted,
        priority: orgItem.priority
      ) {
        updateReminder = self.converter.toCommonReminder(reminder: reminder)
      }

    }
    actionToOrg(action: .update, value: updateReminder)
  }

  func actionToOrg(action: SyncLogger.Action, value: Encodable) {
    self.logger.target = .org
    self.logger.action = action
    self.logger.value = value
    self.logger.log()
  }

  func actionToReminders(action: SyncLogger.Action, value: Encodable) {
    self.logger.target = .reminders
    self.logger.action = action
    self.logger.value = value
    self.logger.log()
  }

  func addItemToReminders(item: CommonReminder) throws -> CommonReminder? {
    actionToReminders(action: .add, value: item)
    if let reminder = try reminders.addReminder(
      string: item.title,
      notes: item.notes,
      listQuery: item.list.id!,
      dueDateComponents: item.dueDate?.toDateComponents(),
      priority: self.converter.toRemindersPriority(priority: item.priority),
      url: nil)
    {
      return self.converter.toCommonReminder(reminder: reminder)
    }
    return nil
  }

  func addListToReminders(list: CommonList) throws {
    actionToReminders(action: .add, value: list)
    if let newList = try self.reminders.newList(with: list.title, source: nil) {
      let newCommonList = self.converter.toCommonList(calendar: newList)
      actionToOrg(action: .update, value: newCommonList)
    }
  }

  func startPolling() {
    DispatchQueue.global().async {
      while true {
        do {
          try self.syncOnce()
        } catch let error {
          print("Failed to sync reminders with error: \(error)")
          exit(1)
        }
        Thread.sleep(forTimeInterval: 10)  // 等待 10 秒
      }
    }
  }

  func monitorFileChanges() {
    let fileURL = URL(fileURLWithPath: self.filePath)
    let fileDescriptor = open(fileURL.path, O_EVTONLY)

    let dispatchSource = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: .write,
      queue: DispatchQueue.global()
    )

    dispatchSource.setEventHandler {
      do {
        dispatchSource.suspend()
        try self.updateHash()
        dispatchSource.resume()
      } catch let error {
        print("Failed to sync reminders with error: \(error)")
      }

    }
    dispatchSource.setCancelHandler {
      close(fileDescriptor)
    }
    dispatchSource.resume()
    RunLoop.main.run()
  }
}
