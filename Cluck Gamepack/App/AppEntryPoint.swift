import SwiftUI

struct AppEntryPoint: View {
    @AppStorage("stringURL") var stringURL = ""
    @AppStorage("firstOpenApp") var firstOpenApp = true

    @State private var selectedRoute: Route?

    enum Route {
        case launch, privacy
    }

    var body: some View {
        ZStack {
            Group {
                switch selectedRoute {
                case .privacy:
                    PrivacyView()
                case .launch:
                    CGLaunchView()
                case .none:
                    Color.clear
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: selectedRoute)
        }
        .onAppear(perform: {
            DispatchQueue.main.async {
                if !stringURL.isEmpty {
                    AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
                    selectedRoute = .privacy
                } else {
                    AppDelegate.orientationLock = .portrait
                    selectedRoute = .launch
                }
            }
        })
    }
}
