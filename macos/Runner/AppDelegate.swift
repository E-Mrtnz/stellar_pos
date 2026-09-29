import Cocoa
import FlutterMacOS
import FirebaseCore

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    FirebaseConfiguration.shared.setLoggerLevel(.max)
    super.init()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
