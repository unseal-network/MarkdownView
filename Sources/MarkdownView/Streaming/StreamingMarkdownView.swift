import SwiftUI
import Markdown

/// Drives the streaming render pipeline with buffered character reveal.
///
/// Text arrives in chunks but is revealed character-by-character. On each
/// content change `.task(id:)` advances `revealedCount` immediately (before
/// any `await`) so that even rapid-fire cancellations make progress. A
/// follow-up loop catches up if there is a large backlog.
@MainActor
struct StreamingMarkdownView: View {
    let content: MarkdownContent
    let configuration: MarkdownRendererConfiguration

    @State private var revealedCount: Int = 0
    @State private var targetCount: Int = 0
    @State private var lastHapticCount: Int = 0

    private let baseCharsPerSecond: Double = 40

    var body: some View {
        let document = content.parse(options: parseOptions)
        let textMap = TextNodeMap.build(from: document)
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
        config.streamingRevealedCount = revealedCount
        return config
    }

    private func updateAndReveal() async {
        let document = content.parse(options: parseOptions)
        let total = TextNodeMap.build(from: document).totalVisibleChars

        if targetCount == 0, total > 0 {
            revealedCount = max(0, total - 1)
        }
        targetCount = total

        // Advance BEFORE any await — survives rapid task cancellation
        advanceReveal()
        triggerHaptic()

        // Catch up remaining backlog at ~60fps
        while revealedCount < targetCount {
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            advanceReveal()
            triggerHaptic()
        }
    }

    private func advanceReveal() {
        let backlog = targetCount - revealedCount
        guard backlog > 0 else { return }
        let chars = max(1, backlog / 5)
        revealedCount = min(targetCount, revealedCount + chars)
    }

    private func triggerHaptic() {
        #if os(iOS)
        if revealedCount - lastHapticCount >= 5 {
            lastHapticCount = revealedCount
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
