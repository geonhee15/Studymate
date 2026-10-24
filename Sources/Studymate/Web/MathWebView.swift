import AppKit
import SwiftUI
import WebKit

/// One web page per bridge. Views call `setContent` / `run`; the page calls back through `onMessage`.
/// JavaScript is queued until the page reports `ready`, so callers never have to wait for the load.
@MainActor
final class WebBridge {
    var onMessage: ((String, [String: Any]) -> Void)?
    fileprivate(set) var isReady = false
    fileprivate var queue: [String] = []
    fileprivate weak var webView: WKWebView?

    func run(_ js: String) {
        if isReady, let webView {
            webView.evaluateJavaScript(js) { _, error in
                if let error { NSLog("Studymate web: %@", error.localizedDescription) }
            }
        } else {
            queue.append(js)
        }
    }

    /// Replaces the page body (#root) with the given HTML fragment and typesets the math in it.
    func setContent(_ html: String) {
        run("sm.setContent(\(WebTemplate.jsString(html)));")
    }

    fileprivate func markReady() {
        isReady = true
        let pending = queue
        queue.removeAll()
        for js in pending { run(js) }
    }

    fileprivate func reset() {
        isReady = false
    }
}

struct MathWebView: NSViewRepresentable {
    let bridge: WebBridge

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "studymate")
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        bridge.webView = webView
        bridge.reset()
        webView.loadHTMLString(WebTemplate.page(), baseURL: WebTemplate.baseURL)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if bridge.webView !== nsView { bridge.webView = nsView }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "studymate")
        nsView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        let bridge: WebBridge
        init(bridge: WebBridge) { self.bridge = bridge }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            MainActor.assumeIsolated {
                if type == "ready" {
                    bridge.markReady()
                    bridge.run("sm.setAccent(\(WebTemplate.jsString(ThemeManager.shared.current.accentHex)));")
                } else if type == "link", let href = body["href"] as? String, let url = URL(string: href) {
                    NSWorkspace.shared.open(url)
                }
                bridge.onMessage?(type, body)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Everything but the initial template load opens outside (links in solutions, AoPS pages …).
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
