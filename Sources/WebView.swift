import SwiftUI
import WebKit

/// 全屏 WKWebView：承载 ws-scrcpy 等串流页面
struct WebContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var title: String
    let reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.backgroundColor = .black
        web.isOpaque = false
        if #available(iOS 16.4, *) {
            web.isInspectable = true   // Safari 远程调试
        }
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        // 目标 URL 变了 → 重新加载
        if context.coordinator.loadedURL != url.absoluteString {
            context.coordinator.loadedURL = url.absoluteString
            web.load(URLRequest(url: url))
            return
        }
        // 手动刷新令牌
        if context.coordinator.reloadToken != reloadToken {
            context.coordinator.reloadToken = reloadToken
            web.reload()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebContainer
        var loadedURL: String?
        var reloadToken: Int = 0

        init(_ parent: WebContainer) {
            self.parent = parent
            self.loadedURL = parent.url.absoluteString
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.title = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        /// 处理 target="_blank" / window.open
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let u = navigationAction.request.url {
                webView.load(URLRequest(url: u))
            }
            return nil
        }

        /// alert / confirm / prompt 兜底
        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            completionHandler()
        }
    }
}
