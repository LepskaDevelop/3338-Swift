import SwiftUI
import UserNotifications
import UIKit
import Combine

struct CGLaunchView: View {
    
    @AppStorage("firstOpenApp") var firstOpenApp = true
    @AppStorage("stringURL") var stringURL = ""
    
    @Environment(\.scenePhase) private var scenePhase

    @State private var showPrivacy = false
    @State private var showHome = false

    @State private var responded = false
    @State private var minSplashDone = false
    @State private var fired = false
    @State private var minTimer: DispatchWorkItem?
    @State private var pollTimer: Timer?
    
    @State private var progress: CGFloat = 0.0

    private let minSplash: TimeInterval       = 2.0
    private let postConsentDelay: TimeInterval = 2.0

    // простая константа окружения
    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

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
            startMinSplash()
            startAuthPolling()
        }
        .onDisappear {
            minTimer?.cancel()
            pollTimer?.invalidate()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    if settings.authorizationStatus == .notDetermined {
                        print("⚠️ User dismissed system permission alert — treating as denied")
                        DispatchQueue.main.async {
                            self.responded = true
                            self.tryProceed()
                        }
                    }
                }
            }
        }
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let hasResponded = (settings.authorizationStatus != .notDetermined)
                DispatchQueue.main.async {
                    if self.responded != hasResponded {
                        self.responded = hasResponded
                        self.tryProceed()
                    } else {
                        self.tryProceed()
                    }
                }
            }
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func tryProceed() {
        guard !fired else { return }

        if isSimulator {
            guard minSplashDone else { return }
            goNext(after: 0)
            return
        }

        if responded && minSplashDone {
            goNext(after: postConsentDelay)
        }
    }

    private func goNext(after delay: TimeInterval) {
        fired = true
        pollTimer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if !stringURL.isEmpty {
                AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
                showPrivacy = true
            } else if firstOpenApp {
                AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
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
