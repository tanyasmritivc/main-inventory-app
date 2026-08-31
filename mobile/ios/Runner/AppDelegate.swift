import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pushResult: FlutterResult?
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "FindEZPushNotifications") {
      let channel = FlutterMethodChannel(name: "com.findez.app/push", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "register" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.registerForPush(result: result)
      }
      pushChannel = channel
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerForPush(result: @escaping FlutterResult) {
    pushResult = result
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error = error {
        self.finishPushRegistration(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
      } else if !granted {
        self.finishPushRegistration(FlutterError(code: "permission_denied", message: "Notifications are disabled.", details: nil))
      } else {
        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
      }
    }
  }

  private func finishPushRegistration(_ value: Any?) {
    DispatchQueue.main.async {
      self.pushResult?(value)
      self.pushResult = nil
    }
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
}
