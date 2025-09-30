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
        log("✅ Firebase configured, isAutoInitEnabled=\(Messaging.messaging().isAutoInitEnabled)")

        UserDefaults.standard.set(0, forKey: "fcmDistinctSinceLaunch")
        UserDefaults.standard.removeObject(forKey: "fcmPrevToken")

        registerForPushNotifications(application: application)
        return true
    }

    // MARK: - APNs callbacks
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let apns = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        log("📬 APNs token: \(apns)")

        Messaging.messaging().apnsToken = deviceToken
        UserDefaults.standard.set(true, forKey: "apnsRegistered")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "apnsRegisteredAt")
        NotificationCenter.default.post(name: .apnsRegistered, object: nil)

        Messaging.messaging().token { [weak self] token, error in
            if let error = error { self?.log("❗️ FCM token re-fetch error (after APNs): \(error)"); return }
            guard let token, !token.isEmpty else { self?.log("⚠️ FCM token empty on re-fetch after APNs"); return }
            self?.saveAndBroadcastFCMToken(token, source: "after APNs")
            StartupGate.shared.notifyFCMTokenUpdated()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        log("❌ APNs register failed: \(error)")
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    // MARK: - Private
    fileprivate func registerForPushNotifications(application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            self?.log(error != nil ? "🔔 Permission error: \(String(describing: error))" : "🔔 Notification permission granted: \(granted)")

            StartupGate.shared.markNotificationsResolved()

            if granted {
                DispatchQueue.main.async {
                    self?.log("📮 registerForRemoteNotifications()")
                    application.registerForRemoteNotifications()
                }
            }

            Messaging.messaging().token { [weak self] token, error in
                if let error = error { self?.log("❗️ FCM token fetch after notif resolve error: \(error)"); return }
                guard let token, !token.isEmpty else { self?.log("⚠️ FCM token empty after notif resolve"); return }
                self?.saveAndBroadcastFCMToken(token, source: "after notif resolve")
                StartupGate.shared.notifyFCMTokenUpdated()
            }
        }
    }

    fileprivate func saveAndBroadcastFCMToken(_ token: String, source: String) {
        let prev = UserDefaults.standard.string(forKey: "fcmToken")
        UserDefaults.standard.set(token, forKey: "fcmToken")
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: "fcmTokenUpdatedAt")

        let prevDistinct = UserDefaults.standard.string(forKey: "fcmPrevToken")
        if prevDistinct != token {
            let cnt = UserDefaults.standard.integer(forKey: "fcmDistinctSinceLaunch") + 1
            UserDefaults.standard.set(cnt, forKey: "fcmDistinctSinceLaunch")
            UserDefaults.standard.set(token, forKey: "fcmPrevToken")
        }

        if prev == token {
            log("🔥 FCM token (\(source), SAME): \(token)")
        } else {
            log("🔥 FCM token (\(source), UPDATED): \(token)")
        }

        NotificationCenter.default.post(
            name: .fcmTokenDidUpdate,
            object: nil,
            userInfo: ["token": token, "updatedAt": now]
        )

        StartupGate.shared.notifyFCMTokenUpdated()
    }

    fileprivate func log(_ message: String) {
        #if DEBUG
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[AppDelegate] \(ts) \(message)")
        #else
        print("[AppDelegate] \(message)")
        #endif
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        log("🔔 willPresent (foreground) userInfo=\(notification.request.content.userInfo)")
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        log("🧭 didReceive response (tap) userInfo=\(response.notification.request.content.userInfo)")
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else {
            log("⚠️ didReceiveRegistrationToken -> empty")
            return
        }
        saveAndBroadcastFCMToken(token, source: "delegate")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let fcmTokenDidUpdate = Notification.Name("FCMTokenDidUpdate")
    static let apnsRegistered    = Notification.Name("APNsRegistered")
}




