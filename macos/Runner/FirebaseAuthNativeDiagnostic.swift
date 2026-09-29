import Foundation
import FlutterMacOS
import FirebaseAuth

enum FirebaseAuthNativeDiagnostic {
  static let channelName = "stellar_pos/firebase_auth_native_diagnostic"

  static func register(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
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
  }
}
