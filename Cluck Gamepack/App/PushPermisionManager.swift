import Foundation
import UserNotifications
import UIKit

enum PushConsent: Int {
    case unknown = 0
    case allowed
    case denied
    case skipped
}

final class PushPermissionManager: ObservableObject {
    static let shared = PushPermissionManager()

    @Published private(set) var resolved = false
    @Published private(set) var outcome: PushConsent = .unknown

    private var willResignActiveObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private let consentKey = "pushConsentState"

    private var requestStartTime: Date?
    private var alertLikelyPresented = false

    private init() {
        if let stored = PushConsent(rawValue: UserDefaults.standard.integer(forKey: consentKey)),
           stored != .unknown {
            outcome = stored
            resolved = true
        }
    }

    func requestIfNeeded() {
        guard outcome == .unknown else {
            resolved = true
            return
        }

        print("🔔 PushPermissionManager.requestIfNeeded — starting request")
        requestStartTime = Date()
        alertLikelyPresented = false

        willResignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            print("📴 App will resign active → likely alert visible")
            self?.alertLikelyPresented = true
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleReturnToForeground()
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Permission granted")
                    self.finish(.allowed)
                    (UIApplication.shared.delegate as? AppDelegate)?.registerForRemoteNotifications()
                } else {
                    print("🚫 Permission denied by user")
                    self.finish(.denied)
                }
            }
        }
    }

    private func handleReturnToForeground() {
        guard outcome == .unknown else { return }

        print("🔙 App became active — scheduling alert state check with delay")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    let duration = Date().timeIntervalSince(self.requestStartTime ?? Date.distantPast)
                    print("⏱ Time since request: \(duration)s | Status: \(settings.authorizationStatus.rawValue) | alertLikelyPresented: \(self.alertLikelyPresented)")

                    if settings.authorizationStatus == .notDetermined,
                       self.alertLikelyPresented,
                       duration < 10 {
                        print("🤔 Alert likely dismissed, but delaying flow continuation (no skip)")
                    }
                    else if settings.authorizationStatus == .authorized {
                        print("✅ Push allowed after returning to foreground")
                        self.finish(.allowed)
                        (UIApplication.shared.delegate as? AppDelegate)?.registerForRemoteNotifications()
                    }
                    else if settings.authorizationStatus == .denied {
                        print("🚫 Push denied after returning to foreground")
                        self.finish(.denied)
                    }
                }
            }
        }
    }

    private func finish(_ newOutcome: PushConsent) {
        guard outcome == .unknown else { return }

        print("🎯 finish called with outcome = \(newOutcome)")
        outcome = newOutcome
        resolved = true
        UserDefaults.standard.set(newOutcome.rawValue, forKey: consentKey)

        if let obs = willResignActiveObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = didBecomeActiveObserver { NotificationCenter.default.removeObserver(obs) }

        alertLikelyPresented = false
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: consentKey)
        outcome = .unknown
        resolved = false
        alertLikelyPresented = false
        if let obs = willResignActiveObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = didBecomeActiveObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
