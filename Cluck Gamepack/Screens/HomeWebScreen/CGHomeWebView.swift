import SwiftUI
import WebKit

struct CGHomeWebView: View {
    private let urlString = "https://3338-web-gl.vercel.app/"

    var body: some View {
        WebContainer(url: URL(string: urlString)!)
            .ignoresSafeArea(.all)
            .hideNavigationBar()
    }
}


struct WebContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero

        webView.allowsBackForwardNavigationGestures = true

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
