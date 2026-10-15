//
//  MathFirstMarkdownViewRenderer.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/4/12.
//

import SwiftUI
import Markdown

struct MathFirstMarkdownViewRenderer: MarkdownViewRenderer {
    func makeBody(
        content: MarkdownContent,
        configuration: MarkdownRendererConfiguration
    ) -> some View {
        var configuration = configuration
        var rawText = content.raw.text
        // Most bubbles have no math: skip the extra parse that finds where math may be.
        guard rawText.contains("$") || rawText.contains("\\(") || rawText.contains("\\[")
                || rawText.contains("\\begin{equation") else {
            return CmarkFirstMarkdownViewRenderer().makeBody(content: content, configuration: configuration)
        }
        
        var extractor = ParsingRangesExtractor()
        extractor.visit(content.parse(options: ParseOptions().union(.parseBlockDirectives)))
        for range in extractor.parsableRanges(in: rawText).reversed() {
            let segment = rawText[range]
            let segmentParser = MathParser(text: segment)
            for math in segmentParser.mathRepresentations.reversed() {
                let latex = MathParser.latex(of: math, in: rawText)
                // Display math on lines of its own becomes a centred block; any other math is
                // swapped for a placeholder cmark leaves alone, and drawn inline.
                if !math.kind.inline, MathParser.ownsItsLines(math.range, in: rawText) {
                    let mathIdentifier = configuration.math.appendDisplayMath(latex)
                    rawText.replaceSubrange(math.range, with: "@math(uuid:\(mathIdentifier))")
                } else {
                    rawText.replaceSubrange(math.range, with: MathParser.placeholder(latex, display: false))
                }
            }
        }
        
        let _content = MarkdownContent(raw: .plainText(rawText))
        return CmarkFirstMarkdownViewRenderer()
            .makeBody(content: _content, configuration: configuration)
    }
}
