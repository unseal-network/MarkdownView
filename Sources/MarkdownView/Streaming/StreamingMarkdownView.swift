import SwiftUI
import Markdown

/// Stateful wrapper that drives the streaming render pipeline.
///
/// Tracks the start of each streaming session (`sessionStartCharCount`,
/// `sessionStartDate`). These are set once when the first new character arrives
/// and held fixed for the rest of the session. `StreamingRevealView` uses them
/// as the wave origin so the animation is continuous — not reset per character.
///
/// For mixed content (code blocks, images, tables) where `CmarkNodeVisitor`
/// returns an `AnyView` rather than an `AttributedString`, rendering falls back
/// to `CmarkFirstMarkdownViewRenderer` with no animation.
@MainActor
struct StreamingMarkdownView: View {
    let content: MarkdownContent
    let configuration: MarkdownRendererConfiguration

    @State private var attributedString: AttributedString? = nil
    // Session-level values — set once when the first new char arrives,
    // held fixed so the animation wave is continuous across character updates.
    @State private var sessionStartCharCount: Int = 0
    @State private var sessionStartDate: Date = .now
    @State private var sessionStarted: Bool = false

    var body: some View {
        Group {
            if let attrStr = attributedString {
                StreamingRevealView(
                    attributedText: attrStr,
                    newCharStart: sessionStartCharCount,
                    revealStartDate: sessionStartDate
                )
            } else {
                // Fallback: mixed content or initial render before task fires.
                // Use nonStreamingConfiguration to avoid polluting the renderer cache.
                CmarkFirstMarkdownViewRenderer()
                    .makeBody(content: content, configuration: nonStreamingConfiguration)
            }
        }
        .animation(.none, value: attributedString == nil)
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
            attributedString = nil
            sessionStartCharCount = 0
            sessionStarted = false
            return
        }

        let newCount = newAttrStr.characters.count
        let prevCount = attributedString?.characters.count ?? 0

        if newCount > prevCount, prevCount > 0, !sessionStarted {
            // First new character of this streaming session — lock in the wave origin.
            sessionStartCharCount = prevCount
            sessionStartDate = .now
            sessionStarted = true
        } else if newCount <= prevCount || prevCount == 0 {
            // First render or content fully replaced — no animation needed.
            sessionStartCharCount = newCount
            sessionStarted = false
        }
        // Subsequent chars in the same session: don't touch sessionStart* values.

        attributedString = newAttrStr
    }

    private var nonStreamingConfiguration: MarkdownRendererConfiguration {
        var c = configuration
        c.isStreaming = false
        return c
    }
}
