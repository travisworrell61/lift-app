import SwiftUI
import WebKit
import WidgetKit
import AVFoundation

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
        // Enable the service worker in WKWebView (offline caching). Requires the WKAppBoundDomains
        // array in Info.plist (see project.yml). WKWebView runs SWs ONLY for app-bound domains with
        // this flag set. Cross-origin data fetches (Vercel API) are unaffected — only navigation is limited.
        config.limitsNavigationsToAppBoundDomains = true
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "lift")       // JS → native: widget state
        controller.add(context.coordinator, name: "liftSync")   // JS → native: full log blob → cloud
        controller.add(context.coordinator, name: "liftWake")   // JS → native: keep screen awake during the core timer
        controller.add(context.coordinator, name: "liftSpeak")  // JS → native: core-timer voice cues (AVSpeechSynthesizer)
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

    // Receives messages from the web app: widget state ("lift") and log-sync ("liftSync").
    final class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let json = message.body as? String,
                  let data = json.data(using: .utf8) else { return }

            switch message.name {
            case "lift":
                guard var snapshot = try? JSONDecoder().decode(WorkoutSnapshot.self, from: data) else { return }
                snapshot.updated = Date()
                LiftStore.save(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
            case "liftSync":
                uploadLogs(data)        // data = raw JSON blob of all logs
            case "liftWake":
                // The in-page wake-lock API is unreliable inside WKWebView, so the
                // timer asks native to hold the screen awake ("1" on open, "0" on close).
                let on = (json == "1")
                DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
            case "liftSpeak":
                // {"say": "...", "rate": 1} or {"cancel": true}. Web speech inside WKWebView only gets
                // the compact (robotic) voices; the native engine can use downloaded Enhanced/Premium ones.
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                DispatchQueue.main.async {
                    if obj["cancel"] as? Bool == true { Speaker.shared.cancel() }
                    if let text = obj["say"] as? String, !text.isEmpty {
                        Speaker.shared.say(text, rate: (obj["rate"] as? Double) ?? 1)
                    }
                }
            default:
                break
            }
        }

        // Push the full log blob to the Vercel sync endpoint so the Claude.ai chat can read progress.
        // Secrets live in Secrets.swift (gitignored) — never in the public web repo.
        private func uploadLogs(_ body: Data, retry: Int = 1) {
            guard let url = URL(string: Secrets.syncURL) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.setValue(Secrets.writeSecret, forHTTPHeaderField: "x-write-secret")
            req.httpBody = body
            URLSession.shared.dataTask(with: req) { [weak self] _, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let ok = error == nil && (200...299).contains(code)
                if ok {
                    NSLog("LIFT sync: uploaded (\(code))")
                } else if retry > 0 {
                    // one retry after a short delay (transient network / cold start)
                    NSLog("LIFT sync: upload failed (code \(code), err \(error?.localizedDescription ?? "none")) — retrying")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.uploadLogs(body, retry: retry - 1) }
                } else {
                    NSLog("LIFT sync: upload failed twice (code \(code)) — will re-send on next save/open")
                }
            }.resume()
        }
    }
}

// Core-timer voice. Picks the most natural English voice installed on the phone:
// Premium > Enhanced > the system default. (Siri voices are not available to apps — Apple restriction.)
final class Speaker: NSObject {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?
    private var picked = false

    override init() {
        super.init()
        // Let the system manage the speech audio session: plays over AirPods/music without
        // touching the web view's own session (the timer beeps).
        synth.usesApplicationAudioSession = false
    }

    // Ranking: Premium > Enhanced > ex-Siri compact voices (Nicky, Aaron, …) > anything else; en-US first.
    // Novelty and "eloquence" (Eddy, Flo, Grandma…) voices are never picked. Siri's own voices are not
    // offered to apps by iOS, so the ex-Siri compact bundle is the most natural fallback.
    static let preferredSiri = ["Nicky", "Aaron"]
    private static func score(_ v: AVSpeechSynthesisVoice, lang: String) -> Int {
        var s = v.quality.rawValue * 100                      // default 1, enhanced 2, premium 3
        if v.identifier.contains("ttsbundle.siri_") { s += 50 }
        if let i = preferredSiri.firstIndex(of: v.name) { s += 10 - i }
        if v.language == lang { s += 5 } else if v.language == "en-US" { s += 3 }
        return s
    }
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let lang = AVSpeechSynthesisVoice.currentLanguageCode()
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice)
                && !$0.identifier.contains(".eloquence.") && !$0.identifier.contains("speech.synthesis.voice.")
        }
        return candidates.max { score($0, lang: lang) < score($1, lang: lang) }
    }

    func say(_ text: String, rate: Double) {
        if !picked { voice = Speaker.bestVoice(); picked = true }
        let u = AVSpeechUtterance(string: text)
        if let v = voice { u.voice = v }
        // Web rate 1.0 = normal speech; AVSpeech's normal is AVSpeechUtteranceDefaultSpeechRate.
        u.rate = min(AVSpeechUtteranceMaximumSpeechRate,
                     max(AVSpeechUtteranceMinimumSpeechRate, Float(rate) * AVSpeechUtteranceDefaultSpeechRate))
        synth.speak(u)
        writeDiag(lastText: text)
    }

    // Diagnostics: Documents/voice-diag.txt in the app container (no personal data — voice names only).
    private var count = 0
    private func writeDiag(lastText: String) {
        count += 1
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        var lines = ["say calls: \(count)", "last text: \(lastText)",
                     "chosen: \(voice.map { "\($0.name) [\($0.identifier)] q=\($0.quality.rawValue)" } ?? "nil (system default)")",
                     "default for \(AVSpeechSynthesisVoice.currentLanguageCode()): \(AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()).map { "\($0.name) [\($0.identifier)] q=\($0.quality.rawValue)" } ?? "none")",
                     "en voices (\(all.count)):"]
        lines += all.map { "  \($0.name) | \($0.language) | q=\($0.quality.rawValue) | \($0.identifier)" }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? lines.joined(separator: "\n").write(to: dir.appendingPathComponent("voice-diag.txt"), atomically: true, encoding: .utf8)
        }
    }

    func cancel() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}
