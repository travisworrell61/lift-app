import SwiftUI
import WebKit
import WidgetKit

// ─────────────────────────────────────────────────────────────
// 🔗 Hosted link (GitHub Pages). Keep the quotes + trailing slash.
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // keeps your logs/history between launches
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "lift")   // JS → native bridge
        config.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 11/255, green: 13/255, blue: 18/255, alpha: 1)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // Receives the workout state from the web app and hands it to the widget.
    final class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "lift",
                  let json = message.body as? String,
                  let data = json.data(using: .utf8) else { return }
            guard var snapshot = try? JSONDecoder().decode(WorkoutSnapshot.self, from: data) else { return }
            snapshot.updated = Date()
            LiftStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
