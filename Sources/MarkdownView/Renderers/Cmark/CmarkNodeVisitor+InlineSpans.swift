//
//  CmarkNodeVisitor+InlineSpans.swift
//  MarkdownView
//

import SwiftUI
import Markdown

/// Inline styles beyond CommonMark, without raw HTML: a whitelist of HTML tags (`<mark>`, `<u>`,
/// `<ins>`, `<sub>`, `<sup>`, `<kbd>`) and `==highlight==`. cmark gives an HTML tag as an
/// `InlineHTML` sibling of the text it wraps (`<mark>` · text · `</mark>`), so tags are paired across
/// one node's children and their style applied to everything between. An unpaired or other tag
/// stays as it was (literal text, or raw HTML when that is allowed).
enum InlineSpanStyle: Hashable {
    case mark, underline, lowered, raised, keyboard

    /// `<mark>` → (.mark, opens), `</mark>` → (.mark, closes); nil for any other HTML.
    static func tag(_ rawHTML: String) -> (style: InlineSpanStyle, opens: Bool)? {
        var tag = rawHTML.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard tag.hasPrefix("<"), tag.hasSuffix(">") else { return nil }
        tag = String(tag.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        let opens = !tag.hasPrefix("/")
        if !opens { tag = String(tag.dropFirst()).trimmingCharacters(in: .whitespaces) }
        let style: InlineSpanStyle? = switch tag {
        case "mark": .mark
        case "u", "ins": .underline
        case "sub": .lowered
        case "sup": .raised
        case "kbd": .keyboard
        default: nil
        }
        return style.map { ($0, opens) }
    }
}

extension CmarkNodeVisitor {
    private enum Token {
        case node(any Markup)
        /// Part of a `Text` node split at `==`; `whole` when it is the entire node.
        case text(String, whole: Markdown.Text?)
        /// `==`: whether it may open (text follows) and close (text precedes) a highlight.
        case highlight(canOpen: Bool, canClose: Bool)
        case tag(InlineSpanStyle, opens: Bool, raw: any Markup)
    }

    /// `markup`'s children rendered with the inline spans above applied.
    func visitInlineChildren(of markup: any Markup) -> [MarkdownNodeView] {
        var tokens: [Token] = []
        let children = Array(markup.children)
        for (index, child) in children.enumerated() {
            if let html = child as? InlineHTML, let tag = InlineSpanStyle.tag(html.rawHTML) {
                tokens.append(.tag(tag.style, opens: tag.opens, raw: child))
            } else if let text = child as? Markdown.Text, text.string.contains("==") {
                Self.split(text, before: index > 0, after: index + 1 < children.count, into: &tokens)
            } else {
                tokens.append(.node(child))
            }
        }
        // Without any span syntax, exactly as before.
        guard tokens.contains(where: { if case .node = $0 { false } else { true } }) else {
            return children.map { child in
                var renderer = self
                return renderer.visit(child)
            }
        }
        let paired = Self.pair(tokens)
        var views: [MarkdownNodeView] = []
        var active: [InlineSpanStyle] = []
        for (index, token) in tokens.enumerated() {
            switch token {
            case let .tag(style, opens, raw):
                guard paired.contains(index) else {
                    var renderer = self
                    views.append(renderer.visit(raw)) // unpaired: as any other HTML
                    continue
                }
                if opens {
                    active.append(style)
                } else if let last = active.lastIndex(of: style) {
                    active.remove(at: last)
                }
            case .highlight:
                guard paired.contains(index) else {
                    views.append(styled(MarkdownNodeView("=="), active))
                    continue
                }
                if let last = active.lastIndex(of: .mark) { active.remove(at: last) } else { active.append(.mark) }
            case let .text(string, whole):
                var renderer = self
                let view = renderer.visit(whole ?? Markdown.Text(string))
                views.append(styled(view, active))
            case let .node(child):
                var renderer = self
                views.append(styled(renderer.visit(child), active))
            }
        }
        return views
    }

    /// `text` cut at each `==`. Like emphasis delimiters: an opening `==` has text right after it, a
    /// closing one text right before, so `1 == 2` stays as written.
    private static func split(_ text: Markdown.Text, before: Bool, after: Bool, into tokens: inout [Token]) {
        let string = text.string
        let parts = string.components(separatedBy: "==")
        for (index, part) in parts.enumerated() {
            if !part.isEmpty { tokens.append(.text(part, whole: nil)) }
            guard index < parts.count - 1 else { break }
            let next = parts[index + 1]
            let previous = part
            // At the node's edge, the neighbouring node decides (`==**bold**==`).
            let canOpen = next.first.map { !$0.isWhitespace } ?? (index + 1 == parts.count - 1 && after)
            let canClose = previous.last.map { !$0.isWhitespace } ?? (index == 0 && before)
            tokens.append(.highlight(canOpen: canOpen, canClose: canClose))
        }
    }

    /// Indices of the tags and `==` that have a partner; the others are shown as written.
    private static func pair(_ tokens: [Token]) -> Set<Int> {
        var paired = Set<Int>()
        var openTags: [(style: InlineSpanStyle, index: Int)] = []
        var openHighlight: Int?
        for (index, token) in tokens.enumerated() {
            switch token {
            case let .tag(style, opens, _):
                if opens {
                    openTags.append((style, index))
                } else if let match = openTags.lastIndex(where: { $0.style == style }) {
                    paired.insert(openTags[match].index)
                    paired.insert(index)
                    openTags.removeSubrange(match...)
                }
            case let .highlight(canOpen, canClose):
                if let open = openHighlight, canClose {
                    paired.insert(open)
                    paired.insert(index)
                    openHighlight = nil
                } else if canOpen {
                    openHighlight = index
                }
            default:
                break
            }
        }
        return paired
    }

    /// `view` with `styles` applied when it is text (a view inside, an image say, is left as is).
    private func styled(_ view: MarkdownNodeView, _ styles: [InlineSpanStyle]) -> MarkdownNodeView {
        guard !styles.isEmpty, var text = view.asAttributedString else { return view }
        for style in Set(styles) { InlineSpanStyle.apply(style, to: &text) }
        return MarkdownNodeView(text)
    }
}

extension InlineSpanStyle {
    /// The body size the smaller sub/superscript text scales from.
    @MainActor private static var bodySize: CGFloat {
        #if canImport(UIKit)
        UIFont.preferredFont(forTextStyle: .body).pointSize
        #else
        NSFont.systemFontSize
        #endif
    }

    @MainActor static func apply(_ style: InlineSpanStyle, to text: inout AttributedString) {
        let range = text.startIndex..<text.endIndex
        switch style {
        case .mark:
            text[range].backgroundColor = Color.yellow.opacity(0.4)
        case .underline:
            text[range].underlineStyle = .single
        case .lowered:
            text[range].font = .system(size: bodySize * 0.72)
            text[range].baselineOffset = -bodySize * 0.18
        case .raised:
            text[range].font = .system(size: bodySize * 0.72)
            text[range].baselineOffset = bodySize * 0.36
        case .keyboard:
            for run in text.runs {
                let intent = run.inlinePresentationIntent ?? []
                text[run.range].inlinePresentationIntent = intent.union(.code)
            }
            text[range].backgroundColor = Color.secondary.opacity(0.16)
        }
    }
}

extension InlineSpanStyle {
    /// Emphasis in Chinese, Japanese or Korean: their fonts have no italic face and `Text` draws
    /// them upright, so those characters get the system font slanted (Latin keeps its italic).
    @MainActor static func slantIdeographs(_ text: inout AttributedString) {
        #if canImport(UIKit)
        for run in text.runs where text[run.range].characters.contains(where: isIdeographLike) {
            let bold = run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
            let base = UIFont.systemFont(ofSize: bodySize, weight: bold ? .semibold : .regular)
            let slanted = base.fontDescriptor.withMatrix(CGAffineTransform(a: 1, b: 0, c: 0.2, d: 1, tx: 0, ty: 0))
            text[run.range].font = Font(UIFont(descriptor: slanted, size: bodySize) as CTFont)
        }
        #endif
    }

    private static func isIdeographLike(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        if scalar.properties.isIdeographic { return true }
        switch scalar.value {
        case 0x3000...0x30FF, 0x3100...0x312F, 0xAC00...0xD7AF, 0xFF00...0xFFEF: return true
        default: return false
        }
    }
}
