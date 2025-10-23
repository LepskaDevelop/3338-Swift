import UIKit
import WebKit

// MARK: - WebViewCoordinator

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    var lastLoadedURL: String = ""
    private var redirectCount = 0
    private var wasCatchDetected = false
    private let baseDomain = "http://cluckgamepack.website"
    private let baseSecurityDomain = "https://cluckgamepack.website"
    private var hasHandledScore = false
    private var hasSavedFinalURL = false
    
    var parent: WebViewContainer
    var webView: WKWebView?
    var newWebView: WKWebView?
    
    let onContentLoaded: (() -> Void)?
    private var didLoadContent = false
    
    init(_ parent: WebViewContainer, onContentLoaded: (() -> Void)?) {
        self.parent = parent
        self.onContentLoaded = onContentLoaded
    }
    
    private func triggerContentLoadedIfNeeded() {
        guard !didLoadContent else { return }
        didLoadContent = true
        DispatchQueue.main.async {
            self.onContentLoaded?()
        }
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "iosListener":
            if let urlString = message.body as? String,
               let webview = self.webView,
               !hasHandledScore {
                hasHandledScore = true
                print("📩 [iosListener] Received: \(urlString)")
                parent.load(webview, with: urlString)
            } else {
                print("⚠️ [iosListener] Ignored duplicate score: \(message.body)")
            }
            
        case "contentLoaded":
            triggerContentLoadedIfNeeded()
        case "closeWindow":
            print("🧹 Received closeWindow message from JS")
            if let vc = webView?.findViewController() {
                vc.dismiss(animated: true)
            } else {
                webView?.removeFromSuperview()
            }
            
        default:
            break
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(.allow)
            return
        }
        
        let urlString = url.absoluteString
        print("🔄 Navigation → \(urlString)")
        
        if url.isFileURL || urlString.starts(with: "about:blank") {
            decisionHandler(.allow)
            return
        }
        
        if urlString.contains("catch.php") {
            wasCatchDetected = true
            print("🎯 Detected catch.php: \(urlString)")
            decisionHandler(.allow)
            return
        }

        if wasCatchDetected && (urlString.starts(with: baseDomain) || urlString.starts(with: baseSecurityDomain)) {
            print("🛑 Blocked fallback base domain after catch")
            triggerContentLoadedIfNeeded()
            decisionHandler(.cancel)
            wasCatchDetected = false
            return
        }
        
        let scheme = url.scheme?.lowercased() ?? ""
        if !["http", "https", "about"].contains(scheme) {
            if UIApplication.shared.canOpenURL(url) {
                print("📲 Opening external URL via UIApplication: \(url.absoluteString)")
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            } else {
                print("🚫 Cannot open URL via UIApplication: \(url.absoluteString)")
                decisionHandler(.allow)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           let mimeType = response.mimeType,
           let finalURL = response.url {

            if mimeType == "application/vnd.android.package-archive"
                || mimeType == "application/octet-stream"
                || finalURL.pathExtension.lowercased() == "apk" {

                print("🚫 Blocked APK / binary download → \(finalURL.absoluteString)")
                decisionHandler(.cancel)
                return
            }

            if 200...299 ~= response.statusCode,
               !finalURL.absoluteString.contains("catch.php"),
               !(finalURL.host?.contains(baseDomain) ?? false),
               !hasSavedFinalURL {

                print("✅ Saved final URL: \(finalURL.absoluteString)")
                hasSavedFinalURL = true
                UserDefaults.standard.set(finalURL.absoluteString, forKey: "stringURL")
                triggerContentLoadedIfNeeded()
            }
        }

        decisionHandler(.allow)
    }
    
    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        didLoadContent = false
    }
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        
        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.navigationDelegate = self
        newWebView.uiDelegate = self
        newWebView.allowsBackForwardNavigationGestures = true
        
        newWebView.applyCustomUserAgent()
        let sheetVC = WebSheetViewController(webView: newWebView)
        
        if let topVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController?
            .topMostPresentedViewController() {
            
            topVC.present(sheetVC, animated: true)
        }
        return newWebView
    }
    
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        print("❌ Load failed: \(error.localizedDescription)")
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        webView.allowsBackForwardNavigationGestures = true
    }
}

// MARK: - WebViewContainer load

extension WebViewContainer {
    func load(_ webView: WKWebView, with urlString: String) {
        if urlString.lowercased().hasPrefix("http") || urlString.lowercased().hasPrefix("https"),
           let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        } else if let localURL = Bundle.main.url(forResource: "index", withExtension: "html"),
                  let html = try? String(contentsOf: localURL) {
            webView.loadHTMLString(html, baseURL: localURL.deletingLastPathComponent())
        } else {
            print("⚠️ Не найден URL — \(urlString)")
        }
    }
}

// MARK: - Extension WKWebView

extension WKWebView {
    func applyCustomUserAgent(desktop: Bool = false) {
        let uaBuilder = UserAgentBuilder()
        self.customUserAgent = uaBuilder.build(desktopMode: desktop)
    }
}

private extension UIView {
    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
