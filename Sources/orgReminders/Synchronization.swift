import CommonLibrary
import Dispatch
import EventKit
import Foundation
import OrgLibrary
import RemindersLibrary

public class Synchronization {
  var filePath: String
  var converter: ModelConverter
  var orgSource: OrgSource
  var reminders: Reminders
  var logger: SyncLogger
  var frequency: Int = 1
  var saveCount: Int = 0

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

  @objc func handleRemindersChange() {
    logSync()
  }

  func syncAuto() throws {
    let store = EKEventStore()
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleRemindersChange), name: .EKEventStoreChanged,
      object: store)
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

    try syncArray(orgArray: orgLists, remindersArray: remindersLists) {
      $0.id
    }
    try syncArray(orgArray: orgTodos, remindersArray: remindersItems) {
      $0.externalId
    }
    // try syncLists(orgLists: orgLists, remindersLists: remindersLists)
    // try syncItems(orgItems: orgTodos, remindersItems: remindersItems)
  }

  public func measureTime(name: String, block: () throws -> Void) throws {
    let start = Date()
    try block()
    let end = Date()
    print("[\(name)]Run time :\(end.timeIntervalSince(start)) s")
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

  func addToReminders<T>(from: T) throws -> Encodable? {
    if let list = from as? CommonList {
      return try addListToReminders(list: list)
    }
    if let reminder = from as? CommonReminder {
      return try addReminderToReminders(item: reminder)
    }
    return nil
  }

  func syncArray<T>(orgArray: [T], remindersArray: [T], keyProvider: (T) -> String?) throws {
    let orgDictionary = arrayToDictionary(from: orgArray, keyProvider: keyProvider)
    let remindersDictionary = arrayToDictionary(
      from: remindersArray, keyProvider: keyProvider)
    for item in orgArray {
      guard let id = keyProvider(item) else {
        // There is no id, It is a new item in Org Mode file.
        if let newItem = try addToReminders(from: item) {
          actionToOrg(action: .update, value: newItem)
        }
        continue
      }
      // There is no matched item in Reminders, So It's deleted in Reminders.
      guard let matchedItem = remindersDictionary[id] else {
        actionToOrg(action: .delete, value: item)
        continue
      }
      // Sync Item.
      try syncItem(orgItem: item, remindersItem: matchedItem)
    }
    // There is no matched item in OrgMode, It a new Item in Reminders.
    for item in remindersArray {
      if orgDictionary[keyProvider(item)] == nil {
        actionToOrg(action: .add, value: item)
      }
    }
  }

  func syncList(orgList: CommonList, remindersList: CommonList) throws {
    if orgList.isDeleted {
      let _ = try reminders.deleteList(query: orgList.id!)
    }
    if orgList.title != remindersList.title {
      actionToOrg(action: .update, value: remindersList)
    }
  }

  func syncItem<T>(orgItem: T, remindersItem: T) throws {
    if let org = orgItem as? CommonList,
      let reminders = remindersItem as? CommonList
    {
      try syncList(orgList: org, remindersList: reminders)
    }
    if let org = orgItem as? CommonReminder,
      let reminders = remindersItem as? CommonReminder

    {
      try syncReminder(orgItem: org, remindersItem: reminders)
    }
  }

  func syncReminder(orgItem: CommonReminder, remindersItem: CommonReminder) throws {
    guard
      let orgLastModified = orgItem.lastModified,
      let remindersLastModified = remindersItem.lastModified
    else {
      return
    }
    if orgItem.isDeleted {
      actionToReminders(action: .delete, value: orgItem)
      if let reminder = try self.reminders.delete(
        query: orgItem.externalId!, listQuery: orgItem.list.id!)
      {
        let commonReminder = self.converter.toCommonReminder(reminder: reminder)
        actionToOrg(action: .delete, value: commonReminder)
      }
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

  func actionToOrg<T>(action: SyncLogger.Action, value: T) {
    self.logger.target = .org
    self.logger.action = action
    self.logger.value = value as? Encodable
    self.logger.log()
  }

  func actionToReminders(action: SyncLogger.Action, value: Encodable) {
    self.logger.target = .reminders
    self.logger.action = action
    self.logger.value = value
    self.logger.log()
  }

  func addReminderToReminders(item: CommonReminder) throws -> CommonReminder? {
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

  func addListToReminders(list: CommonList) throws -> CommonList? {
    actionToReminders(action: .add, value: list)
    if let newList = try self.reminders.newList(with: list.title, source: nil) {
      return self.converter.toCommonList(calendar: newList)
    }
    return nil
  }

  func logSync() {
    let logger = SyncLogger()
    logger.action = .sync
    logger.target = .org
    logger.value = CommonList(title: "0", id: "0")
    logger.log()
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
        self.saveCount += 1
        if self.saveCount == self.frequency {
          self.logSync()
          self.saveCount = 0
        }
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
