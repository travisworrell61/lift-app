import SwiftUI
import WebKit

// ─────────────────────────────────────────────────────────────
// 🔗 STEP 1: paste YOUR hosted link here (from GitHub Pages /
//    Cloudflare / Netlify). Keep the quotes and the trailing slash.
// ─────────────────────────────────────────────────────────────
let APP_URL = URL(string: "https://travisworrell61.github.io/lift-app/")!

@main
struct LIFTApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: APP_URL)
                .ignoresSafeArea()        // full-screen, like a native app
                .preferredColorScheme(.dark)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // keeps your logs/history between launches
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 11/255, green: 13/255, blue: 18/255, alpha: 1)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
