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

    private var didEnterBgObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private let consentKey = "pushConsentState"
    private var wentToBackground = false

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

        didEnterBgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.wentToBackground = true
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleReturnFromBackgroundIfNeeded()
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    self.finish(.allowed)
                    (UIApplication.shared.delegate as? AppDelegate)?.registerForRemoteNotifications()
                } else {
                    self.finish(.denied)
                }
            }
        }
    }

    private func handleReturnFromBackgroundIfNeeded() {
        guard outcome == .unknown, wentToBackground else { return }
        wentToBackground = false

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                guard self.outcome == .unknown else { return }
                if settings.authorizationStatus == .notDetermined {
                    self.finish(.skipped)
                }
            }
        }
    }

    private func finish(_ newOutcome: PushConsent) {
        guard outcome == .unknown else { return }

        outcome = newOutcome
        resolved = true
        UserDefaults.standard.set(newOutcome.rawValue, forKey: consentKey)

        if let obs = didEnterBgObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = didBecomeActiveObserver { NotificationCenter.default.removeObserver(obs) }
        wentToBackground = false
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: consentKey)
        outcome = .unknown
        resolved = false
        if let obs = didEnterBgObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = didBecomeActiveObserver { NotificationCenter.default.removeObserver(obs) }
        wentToBackground = false
    }
}
