import SwiftUI
import WebKit

/// Plays a Petfinder video. Petfinder sends each video as an HTML `<iframe>`
/// (usually YouTube), so we show it in a small web view.
struct PetVideoView: UIViewRepresentable {
    let embedHTML: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Remembers what's loaded so screen updates don't restart the video.
    final class Coordinator {
        var loadedEmbed: String?
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedEmbed != embedHTML else { return }
        context.coordinator.loadedEmbed = embedHTML
        // Wrap the iframe so it fills the view.
        let html = """
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { margin: 0; padding: 0; height: 100%; background: transparent; }
          iframe { width: 100% !important; height: 100% !important; border: 0; }
        </style>
        </head><body>\(embedHTML)</body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.petfinder.com"))
    }
}
