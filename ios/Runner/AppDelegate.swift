import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import AVFoundation
import AuthenticationServices

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    if #available(iOS 10.0, *) {
      // For iOS 10 display notification (sent via APNS)
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    Messaging.messaging().delegate = self
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle the reception of APNS token
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Forward the APNS token to Firebase
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle the failure of APNS token registration
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // Handle URL scheme opening
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("App opened with URL: \(url.absoluteString)")
    // Let the flutter_web_auth_2 plugin handle the URL
    return super.application(app, open: url, options: options)
  }
  
  // Handle universal links
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      print("App opened with universal link: \(url.absoluteString)")
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    
    // Note: This callback is fired at each app startup and whenever a new token is generated.
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
    // TODO: If necessary send token to application server.
  }
}
