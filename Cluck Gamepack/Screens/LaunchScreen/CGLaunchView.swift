import SwiftUI
import UIKit
import Combine

struct CGLaunchView: View {
    @AppStorage("firstOpenApp") var firstOpenApp = true
    @AppStorage("stringURL") var stringURL = ""
    
    @StateObject private var pushManager = PushPermissionManager.shared
    
    @State private var showPrivacy = false
    @State private var showHome = false
    @State private var minSplashDone = false
    @State private var fired = false
    @State private var minTimer: DispatchWorkItem?
    @State private var progress: CGFloat = 0.0
    
    private let minSplash: TimeInterval = 2.0
    private let postConsentDelay: TimeInterval = 1.5
    
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
                NavigationLink(destination: PrivacyView(), isActive: $showPrivacy) { EmptyView() }
                NavigationLink(destination: CGHomeWebView(), isActive: $showHome) { EmptyView() }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            pushManager.requestIfNeeded()
        }
        .onChange(of: pushManager.resolved) { _ in
            tryProceed()
        }
    }
    
    private func startMinSplash() {
        progress = 0.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.linear(duration: minSplash)) {
                progress = 0.7
            }
        }

        minTimer?.cancel()
        let w = DispatchWorkItem {
            minSplashDone = true
            tryProceed()
        }
        minTimer = w
        DispatchQueue.main.asyncAfter(deadline: .now() + minSplash, execute: w)
    }

    private func tryProceed() {
        guard !fired else { return }

        if isSimulator {
            guard minSplashDone else { return }
            animateToFullAndProceed()
            return
        }

        guard minSplashDone, pushManager.resolved else { return }
        animateToFullAndProceed()
    }

    private func animateToFullAndProceed() {
        fired = true
        withAnimation(.easeInOut(duration: postConsentDelay)) {
            progress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + postConsentDelay) {
            if !stringURL.isEmpty || firstOpenApp {
                AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
                showPrivacy = true
            } else {
                AppDelegate.orientationLock = .portrait
                showHome = true
            }
        }
    }
}

// MARK: - Loader View

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
                    LinearGradient(colors: [.green1, .green1],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LinearGradient(colors: [.white, .white],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                lineWidth: 2)
                )
                .frame(width: progress * 280, height: 35)
                .animation(.linear(duration: 0.25), value: progress)
        }
        .frame(width: 280)
    }
}

#Preview {
    CGLaunchView()
}
