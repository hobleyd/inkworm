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

// Receives ePubs handed over by other apps ("Open in…" / share sheet) and
// passes them to Dart over the same channel protocol as the Windows runner:
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
    guard let url = contexts.map(\.url).first(where: { $0.isFileURL && $0.pathExtension.lowercased() == "epub" }),
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
      if url.path.contains("/Inbox/") {
        try? fileManager.removeItem(at: url)
      }
      return destination.path
    } catch {
      return url.path
    }
  }
}
