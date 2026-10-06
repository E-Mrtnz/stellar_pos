import Cocoa
import FlutterMacOS

private let debtStatementShareChannelName = "stellar_pos/debt_statement_share"

private final class DebtStatementShareCoordinator: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
  private var picker: NSSharingServicePicker?
  private var completion: ((String) -> Void)?
  private var completed = false

  func present(items: [URL], in window: NSWindow, completion: @escaping (String) -> Void) {
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
    proposedSharingServices
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
    self
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

  func finishForReplacement() {
    picker?.close()
    completion = nil
    picker = nil
    completed = true
  }
}

private final class StellarPosDebtStatementSharePlugin: NSObject, FlutterPlugin {
  private weak var window: MainFlutterWindow?
  private var coordinator: DebtStatementShareCoordinator?

  init(window: MainFlutterWindow) {
    self.window = window
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    // Registration is performed explicitly by MainFlutterWindow for its
    // FlutterViewController/engine so this plugin is attached to the exact
    // messenger used by the running Dart isolate.
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    let missingFiles = urls.filter {
      !FileManager.default.fileExists(atPath: $0.path)
    }

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

    DispatchQueue.main.async { [weak self] in
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

      guard
        let window = self.window ?? NSApp.mainWindow ?? NSApp.keyWindow
      else {
        result(
          FlutterError(
            code: "WINDOW_UNAVAILABLE",
            message: "No se encontró una ventana principal de macOS.",
            details: nil
          )
        )
        return
      }

      self.coordinator?.finishForReplacement()

      let coordinator = DebtStatementShareCoordinator()
      self.coordinator = coordinator

      coordinator.present(items: urls, in: window) { [weak self] status in
        result(status)
        if self?.coordinator === coordinator {
          self?.coordinator = nil
        }
      }
    }
  }
}

class MainFlutterWindow: NSWindow {
  private var debtStatementSharePlugin: StellarPosDebtStatementSharePlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame

    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController.engine)

    // Register the sharing feature through Flutter's native macOS plugin
    // registrar. This attaches the method-call delegate to the exact
    // FlutterBinaryMessenger used by this window's Flutter engine.
    let registrar = flutterViewController.registrar(
      forPlugin: "StellarPosDebtStatementSharePlugin"
    )
    let channel = FlutterMethodChannel(
      name: debtStatementShareChannelName,
      binaryMessenger: registrar.messenger
    )
    let plugin = StellarPosDebtStatementSharePlugin(window: self)

    registrar.addMethodCallDelegate(plugin, channel: channel)
    debtStatementSharePlugin = plugin

    super.awakeFromNib()
  }
}
