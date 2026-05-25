import SwiftUI
import Markdown

/// Stateful wrapper that drives the streaming render pipeline.
///
/// On each content change it renders via `CmarkNodeVisitor`, extracts the
/// resulting `AttributedString`, computes how many characters are new, and
/// hands the result to `StreamingRevealView`.
///
/// For mixed content (code blocks, images, tables) where `CmarkNodeVisitor`
/// returns an `AnyView` rather than an `AttributedString`, rendering falls back
/// to `CmarkFirstMarkdownViewRenderer` with no animation.
@MainActor
struct StreamingMarkdownView: View {
    let content: MarkdownContent
    let configuration: MarkdownRendererConfiguration

    @State private var attributedString: AttributedString? = nil
    @State private var previousCharCount: Int = 0
    @State private var revealStartDate: Date = .now

    var body: some View {
        Group {
            if let attrStr = attributedString {
                StreamingRevealView(
                    attributedText: attrStr,
                    newCharStart: previousCharCount,
                    revealStartDate: revealStartDate
                )
            } else {
                // Fallback: mixed content or initial render before task fires.
                // Use nonStreamingConfiguration to avoid polluting the renderer cache.
                CmarkFirstMarkdownViewRenderer()
                    .makeBody(content: content, configuration: nonStreamingConfiguration)
            }
        }
        .environment(\.markdownRendererConfiguration, configuration)
        .task(id: content) {
            updateContent()
        }
    }

    private func updateContent() {
        var parseOptions = ParseOptions()
        if !configuration.allowedBlockDirectiveRenderers.isEmpty {
            parseOptions.insert(.parseBlockDirectives)
        }

        var visitor = CmarkNodeVisitor(configuration: configuration)
        let document = content.parse(options: parseOptions)
        guard let newAttrStr = visitor.visit(document).asAttributedString else {
            // Mixed content: clear attributedString so body falls back to CmarkFirstMarkdownViewRenderer
            attributedString = nil
            return
        }

        let newCount = newAttrStr.characters.count
        let prevCount = attributedString?.characters.count ?? 0

        if newCount > prevCount, prevCount > 0 {
            // New characters arrived — start a reveal wave from where we left off
            previousCharCount = prevCount
            revealStartDate = .now
        } else {
            // First render or content replaced: show all chars as already revealed
            previousCharCount = newCount
        }

        attributedString = newAttrStr
    }

    /// Configuration with isStreaming disabled, used for the mixed-content fallback
    /// so CmarkFirstMarkdownViewRenderer's cache is not polluted with streaming renders.
    private var nonStreamingConfiguration: MarkdownRendererConfiguration {
        var c = configuration
        c.isStreaming = false
        return c
    }
}
