import Flutter
import UIKit
import Security
import LocalAuthentication

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.findez.dashboard/session",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.findez.dashboard",
        kSecAttrAccount as String: "founder-session"
      ]
      switch call.method {
      case "unlock":
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Open your private founder dashboard") { success, _ in
          DispatchQueue.main.async { result(success) }
        }
      case "read":
        var read = query
        read[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &item)
        if status == errSecItemNotFound { result(nil) }
        else if status == errSecSuccess, let data = item as? Data {
          result(String(data: data, encoding: .utf8))
        } else { result(FlutterError(code: "keychain", message: "Unlock your iPhone and sign in again.", details: nil)) }
      case "write":
        guard let text = call.arguments as? String, let bytes = text.data(using: .utf8) else {
          result(FlutterError(code: "session", message: "Could not save this session.", details: nil)); return
        }
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if status == errSecItemNotFound {
          var add = query
          add[kSecValueData as String] = bytes
          add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
          status = SecItemAdd(add as CFDictionary, nil)
        }
        if status == errSecSuccess { result(nil) }
        else { result(FlutterError(code: "keychain", message: "Could not securely save your session.", details: nil)) }
      case "clear":
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { result(nil) }
        else { result(FlutterError(code: "keychain", message: "Could not remove your session. Try again.", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
