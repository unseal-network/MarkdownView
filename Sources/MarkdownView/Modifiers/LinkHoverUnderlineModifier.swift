//
//  LinkHoverUnderlineModifier.swift
//  MarkdownView
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

extension View {
    /// Underlines the link under the pointer (a link that wraps over lines is underlined on all of them). Needs
    /// iOS 18 / macOS 15 (a text renderer); earlier, links are left as they are. Off by default.
    nonisolated public func markdownUnderlinesHoveredLinks(_ enabled: Bool = true) -> some View {
        environment(\.markdownRendererConfiguration.underlinesHoveredLinks, enabled)
    }
}

/// Marks a link's runs in the text: `id` tells which link they belong to.
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct MarkdownLinkTextAttribute: TextAttribute {
    var id: Int
}

/// Draws only a line under the runs of the link the pointer is on (the text itself is drawn by the text underneath).
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct MarkdownLinkUnderlineRenderer: TextRenderer {
    var pointer: CGPoint?
    var color: Color
    /// Told whether the pointer is on a link (only when that changes).
    var onOverLink: @Sendable (Bool) -> Void
    var last: LastOver

    final class LastOver: @unchecked Sendable { var value = false }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var hovered: Int?
        if let pointer {
            for line in layout {
                for run in line {
                    if let link = run[MarkdownLinkTextAttribute.self], run.typographicBounds.rect.contains(pointer) {
                        hovered = link.id
                    }
                }
            }
        }
        if last.value != (hovered != nil) {
            last.value = hovered != nil
            onOverLink(hovered != nil)
        }
        guard let hovered else { return }
        for line in layout {
            for run in line where run[MarkdownLinkTextAttribute.self]?.id == hovered {
                let bounds = run.typographicBounds
                let y = bounds.origin.y + 1.5
                var path = Path()
                path.move(to: CGPoint(x: bounds.origin.x, y: y))
                path.addLine(to: CGPoint(x: bounds.origin.x + bounds.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
    }
}

/// The text as it is (so it stays selectable: a text renderer would switch selection off), with the same text over it
/// that draws the underline of the hovered link.
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
struct MarkdownHoverLinkText: View {
    var string: AttributedString
    var color: Color
    @State private var pointer: CGPoint?
    @State private var overLink = false
    @State private var last = MarkdownLinkUnderlineRenderer.LastOver()

    var body: some View {
        Text(string)
            .overlay {
                Self.marked(string)
                    .foregroundStyle(.clear)
                    .textRenderer(MarkdownLinkUnderlineRenderer(
                        pointer: pointer, color: color,
                        onOverLink: { over in DispatchQueue.main.async { overLink = over } }, last: last))
                    .textSelection(.disabled)
                    .allowsHitTesting(false)
            }
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            .onChange(of: overLink) { if overLink { NSCursor.pointingHand.set() } else { NSCursor.iBeam.set() } }
            #endif
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    pointer = location
                    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                    // The selectable text under this sets its own I-beam; a hand is set over it on each move.
                    if overLink { NSCursor.pointingHand.set() }
                    #endif
                case .ended: pointer = nil
                }
            }
    }

    private static func marked(_ string: AttributedString) -> Text {
        var text = Text(verbatim: "")
        var plain = AttributedString()
        var id = 0
        for run in string.runs {
            let piece = AttributedString(string[run.range])
            guard run.link != nil else {
                plain += piece
                continue
            }
            text = Text("\(text)\(Text(plain))\(Text(piece).customAttribute(MarkdownLinkTextAttribute(id: id)))")
            plain = AttributedString()
            id += 1
        }
        return Text("\(text)\(Text(plain))")
    }
}
