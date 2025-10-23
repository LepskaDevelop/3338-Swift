import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: UIResponder, UIApplicationDelegate {

    static var orientationLock: UIInterfaceOrientationMask = .portrait

    // MARK: - Orientation
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }

    // MARK: - Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        log("🚀 didFinishLaunching")

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
        log("✅ Firebase configured")

        requestPushAuthorization()

        return true
    }

    // MARK: - Push Permission Request
    private func requestPushAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let alreadyHandled = UserDefaults.standard.bool(forKey: "pushPermissionHandled")
        if alreadyHandled {
            self.log("ℹ️ Push permission already handled earlier → skipping request")
            return
        }

        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.log("🔔 Push permission not determined → requesting…")
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted {
                                self.log("✅ Permission granted → registering for remote notifications")
                                UIApplication.shared.registerForRemoteNotifications()
                                UserDefaults.standard.set(true, forKey: "pushPermissionHandled")
                                NotificationCenter.default.post(name: .pushPermissionGranted, object: nil)
                            } else {
                                self.log("🚫 Permission denied by user")
                                UserDefaults.standard.set(true, forKey: "pushPermissionHandled")
                                NotificationCenter.default.post(name: .pushPermissionDenied, object: nil)
                            }
                        }
                    }
                case .authorized, .provisional, .ephemeral:
                    self.log("📲 Already authorized → registering for remote notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                    UserDefaults.standard.set(true, forKey: "pushPermissionHandled")
                    NotificationCenter.default.post(name: .pushPermissionGranted, object: nil)
                case .denied:
                    self.log("🚫 Push previously denied by user")
                    UserDefaults.standard.set(true, forKey: "pushPermissionHandled")
                    NotificationCenter.default.post(name: .pushPermissionDenied, object: nil)
                @unknown default:
                    self.log("❓ Unknown authorization state")
                    UserDefaults.standard.set(true, forKey: "pushPermissionHandled")
                    NotificationCenter.default.post(name: .pushPermissionDenied, object: nil)
                }
            }
        }
    }

    // MARK: - APNs token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let apns = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        log("📬 APNs token: \(apns)")

        Messaging.messaging().apnsToken = deviceToken

        Messaging.messaging().token { token, error in
            if let error = error {
                self.log("❗️FCM token fetch error: \(error)")
                return
            }

            guard let token, !token.isEmpty else {
                self.log("⚠️ FCM token empty")
                return
            }

            UserDefaults.standard.set(token, forKey: "fcmToken")
            self.log("🔥 FCM token saved: \(token)")

            NotificationCenter.default.post(name: .fcmTokenDidUpdate, object: nil, userInfo: ["token": token])
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        log("❌ APNs register failed: \(error)")
        NotificationCenter.default.post(name: .pushPermissionDenied, object: nil)
    }

    fileprivate func log(_ message: String) {
        #if DEBUG
        print("[AppDelegate] \(message)")
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else {
            log("⚠️ didReceiveRegistrationToken empty")
            return
        }
        UserDefaults.standard.set(token, forKey: "fcmToken")
        log("🔥 FCM token (delegate): \(token)")
        NotificationCenter.default.post(name: .fcmTokenDidUpdate, object: nil, userInfo: ["token": token])
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let fcmTokenDidUpdate = Notification.Name("fcmTokenDidUpdate")
    static let pushPermissionGranted = Notification.Name("pushPermissionGranted")
    static let pushPermissionDenied = Notification.Name("pushPermissionDenied")
}
