import SwiftUI
import Markdown

/// One top-level block of a streaming document.
///
/// Streaming re-runs the document body for every reveal frame (~30 fps) and every content
/// update. Without this, every block — and every nested view reading the renderer
/// configuration from the environment — rebuilt each time, so cost grew with message length.
/// Here a block is compared by its kind, source range and reveal phase: a block the gradient
/// has fully passed, or not yet reached, renders with a configuration that no longer changes
/// frame to frame, so SwiftUI skips it. Only the block under the gradient keeps re-rendering.
@MainActor
struct StreamingBlockView: View, Equatable {
    private let block: any Markup
    private let key: Key
    private let configuration: MarkdownRendererConfiguration

    enum Phase: Equatable {
        case settled
        case pending
        case revealing(Int)
    }

    struct Key: Equatable {
        let kind: ObjectIdentifier
        let range: SourceRange?
        let phase: Phase
        /// Renderer settings with the per-frame streaming fields stripped.
        let base: MarkdownRendererConfiguration
    }

    init(block: any Markup, start: Int, end: Int, configuration: MarkdownRendererConfiguration) {
        self.block = block
        let revealed = configuration.streamingRevealedCount
        let phase: Phase
        if end <= revealed - configuration.streamingWindowSize {
            phase = .settled
        } else if start >= revealed {
            phase = .pending
        } else {
            phase = .revealing(revealed)
        }
        var stable = configuration
        stable.streamingTextNodeMap = nil
        stable.streamingRevealedCount = .max
        key = Key(kind: ObjectIdentifier(type(of: block)), range: block.range, phase: phase, base: stable)
        // Settled and pending blocks see a configuration that is identical every frame.
        self.configuration = phase == .settled || phase == .pending ? stable : configuration
    }

    nonisolated static func == (lhs: StreamingBlockView, rhs: StreamingBlockView) -> Bool {
        lhs.key == rhs.key
    }

    var body: some View {
        CmarkNodeVisitor(configuration: configuration)
            .makeBody(for: block)
            // Not yet reached by the reveal: keep its layout, show nothing.
            .opacity(key.phase == .pending ? 0 : 1)
    }
}
