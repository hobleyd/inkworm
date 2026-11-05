import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var fileOpenHandler: FileOpenHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "InkwormFileOpen") {
      fileOpenHandler = FileOpenHandler(registrar: registrar)
    }
  }
}

// Receives ePubs handed over by other apps ("Open in…" / share sheet, or an
// inkworm://open URL from Paladin) and passes them to Dart over the same
// channel protocol as the Windows runner:
// getOpenedFile answers the file the app was launched with, and fileOpened
// reports files opened while it is already running.
class FileOpenHandler: NSObject, FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel
  private var pendingPath: String?
  private var dartReady = false

  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "au.com.sharpblue.inkworm/file", binaryMessenger: registrar.messenger())
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "getOpenedFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.dartReady = true
      result(self.pendingPath)
      self.pendingPath = nil
    }
    registrar.addSceneDelegate(self)
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return open(contexts)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return open(URLContexts)
  }

  private func open(_ contexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = contexts.lazy.compactMap({ self.epub(for: $0.url) }).first,
          let path = keep(url) else {
      return false
    }

    if dartReady {
      channel.invokeMethod("fileOpened", arguments: path)
    } else {
      pendingPath = path
    }
    return true
  }

  // An ePub handed over directly, or inkworm://open?file=Book.epub naming one
  // a sibling app (Paladin) has dropped in the shared App Group container. Any
  // app can open an inkworm:// URL, so only a bare file name is honoured.
  private func epub(for url: URL) -> URL? {
    if url.isFileURL {
      return url.pathExtension.lowercased() == "epub" ? url : nil
    }

    guard url.scheme?.lowercased() == "inkworm", url.host == "open",
          let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "file" })?.value,
          name == (name as NSString).lastPathComponent, name != "..",
          name.lowercased().hasSuffix(".epub"),
          let handover = FileOpenHandler.handoverDirectory() else {
      return nil
    }

    let file = handover.appendingPathComponent(name)
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }

  static let appGroup = "group.au.com.sharpblue.books"

  static func handoverDirectory() -> URL? {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent("Handover", isDirectory: true)
  }

  // iOS hands over a copy in Documents/Inbox, and would rename a repeat copy
  // Book-1.epub while the first is still there. Reading progress is keyed by
  // path, so move it to a fixed place named after the book to resume where the
  // reader left off next time.
  private func keep(_ url: URL) -> String? {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }

    let fileManager = FileManager.default
    do {
      let books = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("Books", isDirectory: true)
      try fileManager.createDirectory(at: books, withIntermediateDirectories: true)

      let destination = books.appendingPathComponent(url.lastPathComponent)
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.copyItem(at: url, to: destination)
      if url.path.contains("/Inbox/") || url.deletingLastPathComponent().standardizedFileURL == FileOpenHandler.handoverDirectory()?.standardizedFileURL {
        try? fileManager.removeItem(at: url)
      }
      return destination.path
    } catch {
      return url.path
    }
  }
}
