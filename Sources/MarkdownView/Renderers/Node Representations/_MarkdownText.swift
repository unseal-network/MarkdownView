//
//  _MarkdownText.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/10/20.
//

import SwiftUI

/// A view that displays parsed HTML asynchronously.
///
/// Convert HTML into  `AttributedString` asynchronously to avoid `AttributeGraph` crash.
struct _MarkdownText: View {
    var text: AttributedString
    @State private var attributedString: AttributedString?
    @Environment(\.markdownRendererConfiguration.linkPills) private var linkPills
    /// Inline formulas at the body size, following Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var mathFontSize: CGFloat = 17

    init(_ text: AttributedString) {
        self.text = text
    }
    
    var body: some View {
        Group {
            let shown = attributedString ?? text
            #if canImport(SwiftMath) && canImport(UIKit)
            if shown.containsInlineMath {
                // A paragraph with a formula keeps its text and formulas; a pill in it draws as a link.
                Text.withInlineMath(shown, fontSize: mathFontSize)
            } else {
                styledText(shown)
            }
            #else
            styledText(shown)
            #endif
        }
        .task(id: text) {
            var attributedString = text
            for run in text.runs.reversed() where (run.isHTML ?? false) {
                let range = run.range
                
                if let htmlAttrString = try? AttributedString(
                    NSAttributedString(
                        data: Data(String(text.characters[range]).utf8),
                        options: [
                            .documentType: NSAttributedString.DocumentType.html
                        ],
                        documentAttributes: nil
                    )
                ) {
                    attributedString.replaceSubrange(range, with: htmlAttrString)
                }
            }
            self.attributedString = attributedString
        }
    }

    @ViewBuilder
    private func styledText(_ shown: AttributedString) -> some View {
        if #available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *), let linkPills,
           shown.runs.contains(where: { $0[MarkdownPillAttribute.self] == true }) {
            Self.pillText(shown).textRenderer(MarkdownPillRenderer(fill: linkPills.fill))
        } else {
            Text(shown)
        }
    }

    /// The text with its pills' runs marked for `MarkdownPillRenderer` (a text attribute only a
    /// `Text` can carry, so the runs are joined as texts rather than one attributed string).
    @available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
    private static func pillText(_ string: AttributedString) -> Text {
        var text = Text(verbatim: "")
        var plain = AttributedString()
        for run in string.runs {
            let piece = AttributedString(string[run.range])
            guard run[MarkdownPillAttribute.self] == true else {
                plain += piece
                continue
            }
            text = Text("\(text)\(Text(plain))\(Text(piece).customAttribute(MarkdownPillTextAttribute()))")
            plain = AttributedString()
        }
        return Text("\(text)\(Text(plain))")
    }
}
