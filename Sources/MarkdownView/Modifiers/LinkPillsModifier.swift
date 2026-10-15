//
//  LinkPillsModifier.swift
//  MarkdownView
//

import SwiftUI

extension View {
    /// Draws links whose URL scheme is one of `schemes` as pills: their text on a capsule of `fill`,
    /// in `foreground`, kept on one line where it fits. For mentions, tags and the like that a host
    /// writes into its Markdown as links of its own scheme; a tap still goes to `openURL`.
    ///
    /// The capsule needs iOS 18 / macOS 15 (a text renderer); earlier, the text gets a plain
    /// `fill` highlight instead. Off by default: other links are untouched.
    nonisolated public func markdownLinkPills(schemes: Set<String>, fill: Color, foreground: Color) -> some View {
        environment(
            \.markdownRendererConfiguration.linkPills,
            MarkdownLinkPills(schemes: Set(schemes.map { $0.lowercased() }), fill: fill, foreground: foreground)
        )
    }
}

struct MarkdownLinkPills: Equatable, Sendable {
    var schemes: Set<String>
    var fill: Color
    var foreground: Color

    func matches(_ url: URL) -> Bool {
        schemes.contains(url.scheme?.lowercased() ?? "")
    }

    /// `label` as a pill's text: its spaces unbreakable, a narrow space at each end for the
    /// capsule's padding, the link, the pill's colour and the marker the renderer looks for.
    func pill(_ label: AttributedString, url: URL) -> AttributedString {
        var label = label
        while let space = label.characters.firstIndex(of: " ") {
            label.characters.replaceSubrange(space...space, with: ["\u{00A0}"])
        }
        var pill = AttributedString("\u{202F}") + label + AttributedString("\u{202F}")
        pill.link = url
        pill.foregroundColor = foreground
        pill[MarkdownPillAttribute.self] = true
        if #unavailable(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2) {
            pill.backgroundColor = fill
        }
        return pill
    }
}

/// Marks a pill's runs in the attributed text (`_MarkdownText` gives them `MarkdownPillTextAttribute`).
enum MarkdownPillAttribute: AttributedStringKey {
    typealias Value = Bool
    static let name = "MarkdownView.linkPill"
}

@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct MarkdownPillTextAttribute: TextAttribute {}

/// Draws a capsule behind each pill (adjacent runs of one pill on a line share it), then the text.
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct MarkdownPillRenderer: TextRenderer {
    var fill: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            var pill: CGRect?
            for run in line {
                guard run[MarkdownPillTextAttribute.self] != nil else {
                    if let rect = pill { fillCapsule(rect, in: &context) }
                    pill = nil
                    continue
                }
                let bounds = run.typographicBounds.rect
                pill = pill.map { $0.union(bounds) } ?? bounds
            }
            if let rect = pill { fillCapsule(rect, in: &context) }
            context.draw(line)
        }
    }

    private func fillCapsule(_ rect: CGRect, in context: inout GraphicsContext) {
        let rect = rect.insetBy(dx: 0, dy: -1)
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(fill))
    }
}
