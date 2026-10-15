//
//  InlineMathOrText.swift
//  MarkdownView
//
//  Created by LiYanan2004 on 2025/2/24.
//

import SwiftUI

/// A text node whose math `MathFirstMarkdownViewRenderer` swapped for placeholders before cmark
/// parsed it: the formulas come back as inline-math runs, so the paragraph stays one text.
@preconcurrency
@MainActor
struct InlineMathOrText {
    var text: String
    
    @preconcurrency
    @MainActor
    func makeBody(configuration: MarkdownRendererConfiguration) -> MarkdownNodeView {
        let segments = MathParser.segments(in: text)
        guard segments.contains(where: { if case .math = $0 { true } else { false } }) else {
            return MarkdownNodeView(text)
        }
        var string = AttributedString()
        for segment in segments {
            switch segment {
            case .text(let plain):
                string += AttributedString(plain)
            case .math(let latex, _):
                #if canImport(SwiftMath) && canImport(UIKit)
                string += .inlineMath(latex)
                #else
                string += AttributedString("$\(latex)$")
                #endif
            }
        }
        return MarkdownNodeView(string)
    }
}
