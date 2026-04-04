import Flutter
import UIKit
import FirebaseCore
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase MUST be configured before GeneratedPluginRegistrant so that
    // firebase_auth can register its method channel handlers correctly.
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // CRITICAL: Forward custom-scheme URLs to Firebase Auth.
  // When APNs is not configured, Firebase uses a reCAPTCHA web flow that
  // redirects back via the URL scheme:
  //   app-1-796311176657-ios-7ec6c28264588e189a0cf0://<callback>
  // Firebase Auth intercepts this here. Without this, the URL hits
  // Flutter's go_router which shows "Page Not Found" and discards it,
  // causing the app to fall back to the phone number screen.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  // Required for Universal Links / NSUserActivity on iOS 9+
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }
}
