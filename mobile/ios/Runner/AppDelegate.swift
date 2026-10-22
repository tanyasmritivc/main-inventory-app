import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushResult: FlutterResult?
  private var pushDartReady = false
  private var pushChannel: FlutterMethodChannel?
  private var pendingNotification: [AnyHashable: Any]?
  private var pushGeneration = 0
  private var pushTimeout: DispatchWorkItem?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS needs this delegate before launch finishes to deliver foreground
    // presentation and notification-tap callbacks to the handlers below.
    UNUserNotificationCenter.current().delegate = self
    if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingNotification = notification
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene creates the implicit engine after application launch. Register
  // plugins and custom channels on that engine, not the pre-scene registry.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.applicationRegistrar
    registrar.register(ChatMenuFactory(messenger: registrar.messenger()), withId: "com.findez.app/chat-menu")
    let channel = FlutterMethodChannel(name: "com.findez.app/push", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "requestPermission":
        // Permission belongs to this installation, not an account or APNs token.
        // Keep launch authorization independent of network registration/timeouts.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          guard settings.authorizationStatus == .notDetermined else {
            let allowed = settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional ||
              settings.authorizationStatus == .ephemeral
            DispatchQueue.main.async { result(allowed) }
            return
          }
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
              } else {
                result(granted)
              }
            }
          }
        }
      case "register":
        self?.registerForPush(result: result)
      case "authorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .authorized: status = "authorized"
          case .denied: status = "denied"
          case .provisional: status = "provisional"
          case .ephemeral: status = "ephemeral"
          case .notDetermined: status = "notDetermined"
          @unknown default: status = "notDetermined"
          }
          DispatchQueue.main.async { result(status) }
        }
      case "unregister":
        self?.pushGeneration += 1
        self?.pushTimeout?.cancel()
        self?.pushTimeout = nil
        self?.pushResult?(FlutterError(code: "registration_cancelled", message: "Registration was cancelled.", details: nil))
        self?.pushResult = nil
        self?.pendingNotification = nil
        self?.pushDartReady = false
        UIApplication.shared.unregisterForRemoteNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        result(nil)
      case "getInitialNotification":
        self?.pushDartReady = true
        result(self?.pendingNotification)
        self?.pendingNotification = nil
      case "setBadgeCount":
        let arguments = call.arguments as? [String: Any]
        let count = arguments?["count"] as? Int ?? 0
        UIApplication.shared.applicationIconBadgeNumber = max(0, count)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = channel
  }

  private func registerForPush(result: @escaping FlutterResult) {
    guard pushResult == nil else {
      result(FlutterError(code: "registration_busy", message: "Registration is already in progress.", details: nil))
      return
    }
    pushGeneration += 1
    let generation = pushGeneration
    pushResult = result
    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, self.pushGeneration == generation else { return }
      self.pushGeneration += 1
      self.finishPushRegistration(FlutterError(code: "registration_timeout", message: "Phone alerts could not connect. Try again.", details: nil))
    }
    pushTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      DispatchQueue.main.async {
        guard self.pushGeneration == generation else { return }
        if let error = error {
          self.finishPushRegistration(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
        } else if !granted {
          self.finishPushRegistration(FlutterError(code: "permission_denied", message: "Notifications are disabled.", details: nil))
        } else {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
  }

  private func finishPushRegistration(_ value: Any?) {
    pushTimeout?.cancel()
    pushTimeout = nil
    let result = pushResult
    pushResult = nil
    result?(value)
  }

  private func apnsEnvironment() -> String {
    guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
          let profile = try? String(contentsOfFile: path, encoding: .isoLatin1) else {
      return "production"
    }
    let marker = "<key>aps-environment</key>"
    guard let markerRange = profile.range(of: marker) else { return "production" }
    let remainder = profile[markerRange.upperBound...]
    return remainder.range(of: "<string>development</string>") != nil &&
      (remainder.range(of: "<string>development</string>")!.lowerBound <
       (remainder.range(of: "</dict>")?.lowerBound ?? remainder.endIndex))
      ? "sandbox" : "production"
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    let environment = apnsEnvironment()
    finishPushRegistration(["deviceToken": token, "environment": environment])
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    finishPushRegistration(FlutterError(code: "registration_error", message: error.localizedDescription, details: nil))
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    pushChannel?.invokeMethod("notificationReceived", arguments: nil)
    completionHandler([.banner, .list, .sound, .badge])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if pushChannel == nil || !pushDartReady {
      pendingNotification = userInfo
    } else {
      pushChannel?.invokeMethod("notificationTapped", arguments: userInfo)
    }
    completionHandler()
  }
}


// A real UIKit menu anchored to the composer plus button. The OS controls
// spacing, material, submenu navigation, VoiceOver and outside-tap dismissal.
private final class ChatMenuFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    ChatMenuView(frame: frame, id: viewId, messenger: messenger, args: args)
  }
}

private final class ChatMenuView: NSObject, FlutterPlatformView {
  let button = UIButton(type: .system)
  let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
    channel = FlutterMethodChannel(name: "com.findez.app/chat-menu/\(id)", binaryMessenger: messenger)
    super.init()
    button.frame = frame
    button.backgroundColor = .clear
    button.tintColor = .label
    button.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .regular)), for: .normal)
    button.accessibilityLabel = "Capture or attach"
    button.accessibilityHint = "Opens attachment and context options"
    button.showsMenuAsPrimaryAction = true
    if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
    func action(_ id: String, _ title: String, _ icon: String) -> UIAction {
      UIAction(title: title, image: UIImage(systemName: icon)) { [weak self] _ in
        self?.channel.invokeMethod("selected", arguments: id)
      }
    }
    let attach = UIMenu(title: "Attach", image: UIImage(systemName: "paperclip"), children: [
      action("library", "Photo Library", "photo.on.rectangle"),
      action("camera", "Take Photo", "camera"),
      action("file", "Choose Files", "folder")
    ])
    let context = UIMenu(title: "Add context", image: UIImage(systemName: "text.bubble"), children: [
      action("space", "Spaces", "square.grid.2x2"),
      action("item", "Items", "cube.box"),
      action("project", "Projects", "folder"),
      action("document", "Documents and notes", "doc.text"),
      action("connections", "Connections", "link")
    ])
    button.menu = UIMenu(children: [action("auto_extract", "Auto Extract", "sparkles"), attach,
      action("spreadsheet", "Import inventory", "tablecells"),
      action("barcode", "Scan barcode", "barcode.viewfinder"), context])
    configure(args)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "configure" else { result(FlutterMethodNotImplemented); return }
      self?.configure(call.arguments); result(nil)
    }
  }
  private func configure(_ args: Any?) {
    let values = args as? [String: Any] ?? [:]
    button.isEnabled = values["enabled"] as? Bool ?? true
    button.overrideUserInterfaceStyle = values["dark"] as? Bool == true ? .dark : .light
  }
  func view() -> UIView { button }
  deinit { channel.setMethodCallHandler(nil) }
}
