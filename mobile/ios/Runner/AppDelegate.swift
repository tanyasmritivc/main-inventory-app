import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
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
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "FindEZPushNotifications") {
      let channel = FlutterMethodChannel(name: "com.findez.app/push", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
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
    if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingNotification = notification
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
