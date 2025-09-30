import Foundation
import Combine

final class StartupGate: ObservableObject {
    static let shared = StartupGate()

    @Published private(set) var notifResolved = false
    @Published private(set) var fcmReady = false
    @Published private(set) var isReady = false

    private var bag = Set<AnyCancellable>()
    private var baselineCount = 0

    private init() {
        Publishers.CombineLatest($notifResolved.removeDuplicates(),
                                 $fcmReady.removeDuplicates())
            .map { $0 && $1 }
            .removeDuplicates()
            .sink { [weak self] ready in
                self?.isReady = ready
                if ready { NotificationCenter.default.post(name: .startupReady, object: nil) }
            }
            .store(in: &bag)
    }

    func markNotificationsResolved() {
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: "notifResolvedAt")
        baselineCount = UserDefaults.standard.integer(forKey: "fcmDistinctSinceLaunch")
        DispatchQueue.main.async { self.notifResolved = true }
        reevaluate()
    }

    func notifyFCMTokenUpdated() {
        reevaluate()
    }

    private func reevaluate() {
        let current = UserDefaults.standard.integer(forKey: "fcmDistinctSinceLaunch")
        let token = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        fcmReady = (!token.isEmpty && notifResolved && (current - baselineCount) >= 1)
    }
}

extension Notification.Name {
    static let startupReady = Notification.Name("StartupReady")
}

