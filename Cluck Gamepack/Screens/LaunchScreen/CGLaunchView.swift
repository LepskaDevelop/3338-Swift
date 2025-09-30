import SwiftUI
import UserNotifications
import UIKit
import Combine

struct CGLaunchView: View {
    
    @State private var progress: CGFloat = 0.0
    @State private var isActive = false
   
    @AppStorage("firstOpenApp") var firstOpenApp = true
    @AppStorage("stringURL") var stringURL = ""

    @State private var showPrivacy = false
    @State private var showHome = false
    
    @State var fillAmount: CGFloat = 0.0
    
    @State private var cancellable: AnyCancellable?

    @State private var responded = false
    @State private var granted = false
    @State private var initialChecked = false
    @State private var initialWasNotDetermined = false
    @State private var awaitingSecondToken = false
    @State private var baselineDistinct = 0

    @State private var minSplashDone = false
    @State private var fired = false
    @State private var minTimer: DispatchWorkItem?
    @State private var pollTimer: Timer?

    private let minSplash: TimeInterval = 2
    private let postReadyDelay: TimeInterval = 1.2

    var body: some View {
        NavigationView {
            VStack {
                
                Spacer()
                
                loader
                
                // - Transition
                NavigationLink(
                    destination: PrivacyView(),
                    isActive: $showPrivacy
                ) {
                    EmptyView()
                }
                
                NavigationLink(
                    destination: CGHomeWebView(),
                    isActive: $showHome
                ) {
                    EmptyView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(
                ZStack {
                    Color.white
                    Image(.loadingBackground)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .hideNavigationBar()
        .onAppear {
            progress = 0
            startProgressAnimation()
            startMinSplash()
            startAuthPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fcmTokenDidUpdate)) { _ in
            tryProceed()
        }
        .onDisappear {
            minTimer?.cancel()
            pollTimer?.invalidate()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func startMinSplash() {
        minTimer?.cancel()
        let w = DispatchWorkItem {
            minSplashDone = true
            tryProceed()
        }
        minTimer = w
        DispatchQueue.main.asyncAfter(deadline: .now() + minSplash, execute: w)
    }

    private func startAuthPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            checkNotifAuth()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
        checkNotifAuth()
    }

    private func checkNotifAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let isGranted = (status == .authorized || status == .provisional || status == .ephemeral)
            let hasResponded = (status != .notDetermined)
            DispatchQueue.main.async {
                if !initialChecked {
                    initialChecked = true
                    initialWasNotDetermined = (status == .notDetermined)
                }
                responded = hasResponded
                if isGranted && !granted {
                    granted = true
                    if initialWasNotDetermined {
                        awaitingSecondToken = true
                        baselineDistinct = UserDefaults.standard.integer(forKey: "fcmDistinctSinceLaunch")
                    } else {
                        awaitingSecondToken = false
                    }
                } else {
                    granted = isGranted
                    if !isGranted { awaitingSecondToken = false }
                }
                tryProceed()
            }
        }
    }

    private func tryProceed() {
        guard responded, minSplashDone, !fired else { return }

        let token = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        let currentCnt = UserDefaults.standard.integer(forKey: "fcmDistinctSinceLaunch")

        var canProceed = false
        if granted {
            if awaitingSecondToken {
                canProceed = (!token.isEmpty && (currentCnt - baselineDistinct) >= 1)
            } else {
                canProceed = true
            }
        } else {
            canProceed = (!token.isEmpty && currentCnt >= 1)
        }
        guard canProceed else { return }

        fired = true
        pollTimer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + postReadyDelay) {
            if !stringURL.isEmpty {
                AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
                showPrivacy = true
            } else if firstOpenApp {
                AppDelegate.orientationLock =  [.portrait, .landscapeLeft, .landscapeRight]
                showPrivacy = true
            } else {
                AppDelegate.orientationLock = .portrait
                showHome = true
            }
        }
    }
    
    private func startProgressAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            progress = 1
        }
    }
}

// MARK: - Loader

extension CGLaunchView {
    var loader: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .green1,
                                    .green1
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
            
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            .green1,
                            .green1
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white,
                                    .white
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .frame(width: progress * 280, height: 35)
                .animation(.linear(duration: 3), value: progress)
            
            HStack {
                Text("LOADING...")
                    .foregroundStyle(.yellow1)
                    .font(.system(size: 16, weight: .bold, design: .default))
                
                Text("\(Int(progress * 100))%")
                    .foregroundStyle(.yellow1)
                    .font(.system(size: 16, weight: .bold, design: .default))
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 280)
    }
}

#Preview {
    CGLaunchView()
}
