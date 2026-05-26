import SwiftUI
import Markdown

/// Stateful wrapper that drives the streaming render pipeline.
///
/// Computes a `TextNodeMap` from the AST and injects it into the
/// configuration so `CmarkNodeVisitor.visitText` can apply a trailing
/// gradient to the last few characters. Delegates actual rendering to
/// `CmarkFirstMarkdownViewRenderer` — headings, code blocks, and all
/// other block types render normally with the gradient baked in.
@MainActor
struct StreamingMarkdownView: View {
    let content: MarkdownContent
    let configuration: MarkdownRendererConfiguration

    @State private var lastHapticCount: Int = 0

    var body: some View {
        CmarkFirstMarkdownViewRenderer()
            .makeBody(content: content, configuration: streamingConfiguration)
            .environment(\.markdownRendererConfiguration, streamingConfiguration)
            .task(id: content) {
                triggerHaptic()
            }
    }

    private var streamingConfiguration: MarkdownRendererConfiguration {
        let document = content.parse(options: parseOptions)
        let textMap = TextNodeMap.build(from: document)
        var config = configuration
        config.streamingTextNodeMap = textMap
        return config
    }

    private var parseOptions: ParseOptions {
        var opts = ParseOptions()
        if !configuration.allowedBlockDirectiveRenderers.isEmpty {
            opts.insert(.parseBlockDirectives)
        }
        return opts
    }

    private func triggerHaptic() {
        #if os(iOS)
        let charCount = content.parse(options: parseOptions)
            .children.reduce(0) { $0 + countChars(in: $1) }
        if charCount - lastHapticCount >= 3 {
            lastHapticCount = charCount
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3)
        }
        #endif
    }

    private func countChars(in markup: any Markup) -> Int {
        if let text = markup as? Markdown.Text { return text.plainText.count }
        if markup is SoftBreak { return 1 }
        if markup is LineBreak { return 1 }
        if let code = markup as? InlineCode { return code.code.count }
        return markup.children.reduce(0) { $0 + countChars(in: $1) }
    }
}
