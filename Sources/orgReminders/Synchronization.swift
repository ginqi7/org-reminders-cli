import CommonLibrary
import Dispatch
import Foundation
import OrgLibrary
import RemindersLibrary

public class Synchronization {
  var filePath: String
  var writer: OrgWriter
  var converter: ModelConverter
  var orgSource: OrgSource
  var reminders: Reminders

  init(
    filePath: String
  ) throws {
    self.filePath = filePath
    self.orgSource = try OrgSource(filePath: filePath)
    self.writer = OrgWriter(filePath: filePath, orgSource: self.orgSource)
    self.converter = ModelConverter()
    self.reminders = Reminders()
  }

  func sync(
    type: SyncType
  ) {

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
    try self.writer.updateHash(modifiedDate: converter.dateToStr(date: Date()))
  }

  func syncAuto() throws {
  }

  func syncOnce() throws {

    let reminders = Reminders()
    let remindersLists = self.converter.toCommonLists(calendars: reminders.getLists())
    let remindersItems = self.converter.toCommonReminders(
      reminders: reminders.allReminders(displayOptions: .all))

    try self.orgSource.refreshOrgHeadlines()

    let headlines = self.orgSource.getHeadlines()
    let orgLists = self.converter.toCommonLists(headlines: headlines)
    let orgTodos = self.converter.toCommonReminders(headlines: headlines)
    try syncLists(orgLists: orgLists, remindersLists: remindersLists)
    try syncItems(orgItems: orgTodos, remindersItems: remindersItems)
  }

  public func measureTime(name: String, block: () throws -> Void) throws {
    let start = Date()
    try block()
    let end = Date()
    print("[\(name)]方法调用时间：\(end.timeIntervalSince(start)) 秒")
  }

  func syncAll() throws {
    let reminders = Reminders()
    let remindersLists = self.converter.toCommonLists(calendars: reminders.getLists())
    let remindersItems = self.converter.toCommonReminders(
      reminders: reminders.allReminders(displayOptions: .all))
    let headlines = self.converter.toOrgHeadlines(lists: remindersLists, reminders: remindersItems)
    try self.writer.flushHeadlines(headlines: headlines)

  }

  func syncMonitor() throws {
    startPolling()
    monitorFileChanges()

  }

  func mergeMetaData(lists: [CommonList], reminders: [CommonReminder]) -> [CommonReminder] {
    for reminder in reminders {
      reminder.list = lists.first { list in
        reminder.list.id == list.id
      }!
    }
    return reminders
  }

  func syncItems(orgItems: [CommonReminder], remindersItems: [CommonReminder]) throws {
    let orgDictionary = Dictionary(uniqueKeysWithValues: orgItems.map { ($0.externalId, $0) })
    let remindersDictionary = Dictionary(
      uniqueKeysWithValues: remindersItems.map { ($0.externalId, $0) })

    for orgItem in orgItems {
      if let externalId = orgItem.externalId {
        let matchList = remindersDictionary[externalId]
        if let remindersItem = matchList {
          try syncItem(orgItem: orgItem, remindersItem: remindersItem)
        } else {
          try deleteItemInOrg(item: orgItem)
        }
      } else {
        addItemToReminders(item: orgItem)
      }
    }
    for remindersItem in remindersItems {
      let remindersListId = remindersItem.externalId
      let matchList = orgDictionary[remindersListId]
      if matchList == nil {
        try addItemToOrg(item: remindersItem)
      }
    }

  }

  func syncLists(orgLists: [CommonList], remindersLists: [CommonList]) throws {
    for orgList in orgLists {
      if let orgListId = orgList.id {
        let matchList = remindersLists.first { reminderList in
          orgListId == reminderList.id
        }
        if let remindersList = matchList {
          syncList(orgList: orgList, remindersList: remindersList)
        } else {
          try deleteListInOrg(list: orgList)
        }
      } else {
        try addListToReminders(list: orgList)
      }
    }

    for remindersList in remindersLists {
      let remindersListId = remindersList.id
      let matchList = orgLists.first { orgList in
        remindersListId == orgList.id
      }
      if matchList == nil {
        try addListToOrg(list: remindersList)
      }
    }
  }

  func syncList(orgList: CommonList, remindersList: CommonList) {
    if orgList.title != remindersList.title {
      print("Update Org List: (\(orgList.id!)) \(orgList.title) From Reminders. Not Implemented")
    }
  }

  func syncItem(orgItem: CommonReminder, remindersItem: CommonReminder) throws {
    guard
      let orgLastModified = orgItem.lastModified,
      let remindersLastModified = remindersItem.lastModified
    else {
      return
    }
    if orgLastModified == remindersLastModified {
      return
    }
    var updateReminder = remindersItem
    if orgLastModified > remindersLastModified {
      if let reminder = try reminders.updateItem(
        itemAtIndex: orgItem.externalId!,
        listId: orgItem.list.id!,
        newText: orgItem.title,
        newNotes: orgItem.notes,
        url: nil,
        isCompleted: orgItem.isCompleted,
        priority: orgItem.priority
      ) {
          print("Update Item: \(orgItem.title) (\(orgItem.externalId!)) in Reminders")
          updateReminder = self.converter.toCommonReminder(reminder: reminder)
      }

    } 
    let updateHeadline = self.converter.toOrgHeadline(reminder: updateReminder)
    print(updateHeadline.toJson())
    if let headline = self.orgSource.queryExistHeadline(headline: updateHeadline) {
      updateHeadline.node = headline.node
      try self.writer.updateHeadline(headline: updateHeadline)
      print("Update Item: \(orgItem.title) (\(orgItem.externalId!)) in Org Mode")
    }
    }

  func deleteListInOrg(list: CommonList) throws {
    let headline = self.converter.toOrgHeadline(list: list)
    if let existHeadline = self.orgSource.queryExistHeadline(headline: headline) {
      headline.node = existHeadline.node
      try self.writer.deleteHeadline(headline: headline)
      print("Delete List: \(list.title)\(list.id!) in Org")
    }
  }

  func deleteItemInOrg(item: CommonReminder) throws {
    let headline = self.converter.toOrgHeadline(reminder: item)

    if let existHeadline = self.orgSource.queryExistHeadline(headline: headline) {
      headline.node = existHeadline.node
      try self.writer.deleteHeadline(headline: headline)
      print("Delete List: \(item.title)\(item.externalId!) in Org")
    }
  }

  func addItemToReminders(item: CommonReminder) {
  }

  func addListToReminders(list: CommonList) throws {
    if let newList = try self.reminders.newList(with: list.title, source: nil) {
      let newCommonList = self.converter.toCommonList(calendar: newList)
      let headline = self.converter.toOrgHeadline(list: newCommonList)

      if let existHeadline = self.orgSource.queryExistHeadlineByInfo(headline: headline) {
        headline.node = existHeadline.node
        try writer.updateHeadline(headline: headline)
      }
    }
    print("Add List: \(list.title) to Reminders")
  }

  func addListToOrg(list: CommonList) throws {
    let id = list.id == nil ? "" : "(\(list.id!))"
    try writer.addHeadline(headline: self.converter.toOrgHeadline(list: list))
    print("Add List: \(list.title)\(id) to Org")
  }
  func addItemToOrg(item: CommonReminder) throws {
    let id = item.externalId == nil ? "" : "(\(item.externalId!))"
    try writer.addHeadline(headline: self.converter.toOrgHeadline(reminder: item))
    print("Add Item: \(item.title)\(id) to Org")
  }

  func pollTask() {
    print("轮询任务执行，时间：\(Date())")
  }

  func startPolling() {
    DispatchQueue.global().async {
      while true {
        // do {
        //   throw Error()
        //   // try self.sync()
        // } catch let error {
        //   print("Failed to sync reminders with error: \(error)")
        //   exit(1)
        // }
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
      // do {
      //   // try self.sync()
      // } catch let error {
      //   print("Failed to sync reminders with error: \(error)")
      //   exit(1)
      // }

    }

    dispatchSource.setCancelHandler {
      close(fileDescriptor)
    }
    dispatchSource.resume()
    RunLoop.main.run()
  }

}
