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
