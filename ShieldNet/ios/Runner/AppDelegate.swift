import Flutter
import UIKit
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CALL_CHANNEL = "com.shieldnet.shieldnet/call_screening"
  private let extensionIdentifier = "com.shieldnet.shieldnet.ShieldNetCallExtension"
  private let appGroupSuiteName = "group.com.shieldnet.shieldnet"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let callChannel = FlutterMethodChannel(name: CALL_CHANNEL, binaryMessenger: controller.binaryMessenger)

    callChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      switch call.method {
      case "isCallScreeningActive":
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: self.extensionIdentifier) { status, error in
          if let error = error {
            result(FlutterError(code: "CALLKIT_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(status == .enabled)
          }
        }
        
      case "requestCallScreeningRole":
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: self.extensionIdentifier) { status, error in
          if status == .enabled {
            result(true)
          } else {
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
              DispatchQueue.main.async {
                UIApplication.shared.open(settingsUrl)
              }
            }
            result(false)
          }
        }
        
      case "reloadCallDirectoryExtension":
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: self.extensionIdentifier) { error in
          if let error = error {
            result(FlutterError(code: "RELOAD_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }

      case "syncBlockedNumbersToExtension":
        if let args = call.arguments as? [String: Any],
           let numbers = args["numbers"] as? [Int64] {
          let defaults = UserDefaults(suiteName: self.appGroupSuiteName)
          defaults?.set(numbers, forKey: "blocked_phone_numbers")
          defaults?.synchronize()
          
          CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: self.extensionIdentifier) { error in
            if let error = error {
              result(FlutterError(code: "RELOAD_ERROR", message: error.localizedDescription, details: nil))
            } else {
              result(true)
            }
          }
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Array of Int64 phone numbers required", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
