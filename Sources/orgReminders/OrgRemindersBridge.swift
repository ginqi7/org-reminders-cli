import Foundation
import WebsocketBridgeLibrary

public class OrgRemindersBridge {
  let bridge: WebsocketBridge = WebsocketBridge()
  private var sync: Synchronization? = nil
  let semaphore = DispatchSemaphore(value: 0)
  var semaphores: [String: DispatchSemaphore] = [:]

  public func bridgeAction(logger: SyncLogger) {

    let newUUID = UUID()
    let uuidString = newUUID.uuidString
    let action = logger.action!.rawValue
    let type = logger.getType()
    let base64 = logger.getBase64()
    self.bridge.runInEmacs(
      function: "org-reminders-message-handle",
      uuidString,
      action,
      type,
      base64)
    semaphore.wait()

  }

  public func onMessage(args: [String]) {
    let action = args[0]
    switch action {
    case "sync-once":
      DispatchQueue.main.async {
        do {
          try self.sync?.syncOnce()
        } catch (let error) {
          print(error)
        }
      }
      break
    case "finish":
      let _ = args[1]
      semaphore.signal()
      break
    default:
      print("No handler for \(action)")
    }
  }

  public init(appName: String, serverPort: String) throws {
    self.bridge.onMessage = self.onMessage
    self.bridge.connect(appName: appName, serverPort: serverPort)
    if let file = self.bridge.getEmacsVar(varName: "org-reminders-sync-file") {
      sync = try Synchronization(filePath: file, logLevel: .info, frequency: 1)
      sync?.bridgeAction = bridgeAction
      try sync?.syncAuto()
    }
  }
}
