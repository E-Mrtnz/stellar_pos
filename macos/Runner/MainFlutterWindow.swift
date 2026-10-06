import Cocoa
import FlutterMacOS

private let debtStatementShareChannelName = "stellar_pos/debt_statement_share"

private final class DebtStatementShareCoordinator: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
  private var picker: NSSharingServicePicker?
  private var completion: ((String) -> Void)?
  private var completed = false

  func present(
    items: [URL],
    in window: NSWindow,
    completion: @escaping (String) -> Void
  ) {
    self.completion = completion

    let picker = NSSharingServicePicker(items: items)
    picker.delegate = self
    self.picker = picker

    guard let contentView = window.contentView else {
      finish("error")
      return
    }

    let bounds = contentView.bounds
    let anchorRect = NSRect(
      x: bounds.midX - 1,
      y: bounds.midY - 1,
      width: 2,
      height: 2
    )

    picker.show(
      relativeTo: anchorRect,
      of: contentView,
      preferredEdge: .minY
    )
  }

  func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    sharingServicesForItems items: [Any],
    proposedSharingServices: [NSSharingService]
  ) -> [NSSharingService] {
    return proposedSharingServices
  }

  func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    didChoose service: NSSharingService?
  ) {
    if service == nil {
      finish("dismissed")
    }
  }

  func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    delegateFor service: NSSharingService
  ) -> NSSharingServiceDelegate? {
    return self
  }

  func sharingService(
    _ sharingService: NSSharingService,
    didShareItems items: [Any]
  ) {
    finish("success")
  }

  func sharingService(
    _ sharingService: NSSharingService,
    didFailToShareItems items: [Any],
    error: Error
  ) {
    finish("error")
  }

  private func finish(_ status: String) {
    guard !completed else {
      return
    }

    completed = true
    picker?.close()

    let callback = completion
    completion = nil
    picker = nil

    DispatchQueue.main.async {
      callback?(status)
    }
  }
}

class MainFlutterWindow: NSWindow {
  private var debtStatementShareCoordinator: DebtStatementShareCoordinator?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: debtStatementShareChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "WINDOW_UNAVAILABLE",
            message: "La ventana principal de macOS no está disponible.",
            details: nil
          )
        )
        return
      }

      guard call.method == "shareFiles" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let paths = arguments["paths"] as? [String],
        !paths.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "No se recibieron archivos para compartir.",
            details: nil
          )
        )
        return
      }

      let urls = paths.map { URL(fileURLWithPath: $0) }
      let missingFiles = urls.filter { !FileManager.default.fileExists(atPath: $0.path) }

      guard missingFiles.isEmpty else {
        result(
          FlutterError(
            code: "FILE_NOT_FOUND",
            message: "Uno o más archivos temporales no están disponibles.",
            details: missingFiles.map(\.path)
          )
        )
        return
      }

      DispatchQueue.main.async {
        self.debtStatementShareCoordinator?.finishForReplacement()

        let coordinator = DebtStatementShareCoordinator()
        self.debtStatementShareCoordinator = coordinator

        coordinator.present(items: urls, in: self) { status in
          result(status)
          if self.debtStatementShareCoordinator === coordinator {
            self.debtStatementShareCoordinator = nil
          }
        }
      }
    }

    super.awakeFromNib()
  }
}

private extension DebtStatementShareCoordinator {
  func finishForReplacement() {
    picker?.close()
    completion = nil
    picker = nil
    completed = true
  }
}
