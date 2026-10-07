import SwiftUI
import Markdown

/// Drives the streaming render pipeline with a trailing fade.
///
/// The fade tail moves only when content arrives: each update is a render anyway, so the reveal
/// adds no frames of its own. (A 30 fps reveal loop rebuilt and re-laid out the active block's
/// attributed text every frame — on device that was most of the dropped frames while streaming.)
/// When updates pause, one settle step brings the tail to full opacity.
@MainActor
struct StreamingMarkdownView: View {
    let content: MarkdownContent
    let configuration: MarkdownRendererConfiguration

    /// The content whose tail has settled to full opacity after a pause.
    @State private var settledContent: MarkdownContent?
    @State private var lastHapticCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Quiet time after the last update before the tail settles.
    private static let settleDelay: UInt64 = 220_000_000

    var body: some View {
        let textMap = content.textNodeMap(options: parseOptions)
        let config = streamingConfig(textMap: textMap)

        CmarkFirstMarkdownViewRenderer()
            .makeBody(content: content, configuration: config)
            .environment(\.markdownRendererConfiguration, config)
            .task(id: content) {
                await updateAndReveal()
            }
    }

    private func streamingConfig(textMap: TextNodeMap) -> MarkdownRendererConfiguration {
        var config = configuration
        config.streamingTextNodeMap = textMap
        // Derived, not stored: a stored cursor updated after each chunk rendered every chunk twice.
        let total = textMap.totalVisibleChars
        config.streamingRevealedCount = reduceMotion || settledContent == content
            ? total + configuration.streamingWindowSize : total
        return config
    }

    private func updateAndReveal() async {
        guard !reduceMotion else { return }
        // The newest characters sit faintest at the tail; the next update brightens them.
        triggerHaptic(total: content.textNodeMap(options: parseOptions).totalVisibleChars)
        try? await Task.sleep(nanoseconds: Self.settleDelay)
        guard !Task.isCancelled else { return }
        settledContent = content
    }

    private func triggerHaptic(total: Int) {
        #if os(iOS)
        if configuration.streamingHapticsEnabled, total - lastHapticCount >= 5 {
            lastHapticCount = total
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        }
        #endif
    }

    private var parseOptions: ParseOptions {
        var opts = ParseOptions()
        if !configuration.allowedBlockDirectiveRenderers.isEmpty {
            opts.insert(.parseBlockDirectives)
        }
        return opts
    }
}
