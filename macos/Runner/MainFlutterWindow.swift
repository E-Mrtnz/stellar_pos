import Cocoa
import FlutterMacOS
import FirebaseAuth

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let authDiagnosticChannel = FlutterMethodChannel(
      name: "stellar_pos/firebase_auth_native_diagnostic",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    authDiagnosticChannel.setMethodCallHandler { call, result in
      guard call.method == "signInAnonymously" else {
        result(FlutterMethodNotImplemented)
        return
      }

      Auth.auth().signInAnonymously { authResult, error in
        if let error = error as NSError? {
          result([
            "success": false,
            "domain": error.domain,
            "code": error.code,
            "message": error.localizedDescription,
            "userInfo": error.userInfo.reduce(into: [String: String]()) { partialResult, item in
              partialResult[item.key] = String(describing: item.value)
            }
          ])
          return
        }

        let user = authResult?.user ?? Auth.auth().currentUser
        result([
          "success": true,
          "uid": user?.uid ?? "",
          "isAnonymous": user?.isAnonymous ?? false
        ])
      }
    }

    super.awakeFromNib()
  }
}
