import WebKit
import SwiftUI

struct WebViewContainer: UIViewRepresentable {
    
    var stringURL: String
    var onContentLoaded: (() -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController.add(context.coordinator, name: "iosListener")
        webConfiguration.userContentController.add(context.coordinator, name: "contentLoaded")
        webConfiguration.allowsInlineMediaPlayback = true

        let token = UserDefaults.standard.string(forKey: "fcmToken") ?? ""

        let tokenJSON: String = {
            if let data = try? JSONEncoder().encode(token),
               let string = String(data: data, encoding: .utf8) {
                return string
            } else {
                return "null"
            }
        }()

        let injectJS = "window.fcmToken = \(tokenJSON);"
        print("Inject JS === \(injectJS)")
        let userScript = WKUserScript(source: injectJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webConfiguration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        context.coordinator.webView = webView
        
        webView.applyCustomUserAgent()
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("stringURL = \(stringURL)")
        load(uiView, with: stringURL)
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self, onContentLoaded: onContentLoaded)
    }
}
