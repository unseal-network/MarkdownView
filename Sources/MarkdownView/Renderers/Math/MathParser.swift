//
//  MathParser.swift
//  MarkdownView
//
//  Created by LiYanan2004 on 2025/2/24.
//

import Foundation

/*
 Credits to colinc86/LaTeXSwiftUI
 */
@_spi(MarkdownMath)
public struct MathParser {
    public var text: any StringProtocol
    
    public init(text: some StringProtocol) {
        self.text = text
    }
    
    /// Each math span, left to right, not overlapping. A span runs from its left terminator to the
    /// first unescaped matching right terminator, so `$$\text{$x$}$$` is one span. A single `$`
    /// follows pandoc so prices stay text: it opens only before a non-space, closes only after a
    /// non-space and not before a digit, and does not cross a newline; an unclosed `$` is text.
    public var mathRepresentations: [MathRepresentation] {
        let text = String(self.text)
        var representations: [MathRepresentation] = []
        var index = text.startIndex
        scan: while index < text.endIndex {
            if text[index] == "\\", text[index...].hasPrefix("\\$") {
                index = text.index(index, offsetBy: 2) // `\$` is a literal dollar
                continue
            }
            for kind in MathRepresentation.Kind.allCases where text[index...].hasPrefix(kind.leftTerminator) {
                if escaped(index, in: text) { break }
                let contentStart = text.index(index, offsetBy: kind.leftTerminator.count)
                if let end = closing(kind, from: contentStart, in: text) {
                    let range = index..<text.index(end, offsetBy: kind.rightTerminator.count)
                    representations.append(MathRepresentation(kind: kind, range: offsetRange(range, in: text)))
                    index = range.upperBound
                    continue scan
                }
                if kind == .inlineEquation || kind == .texEquation { break } // `$`/`$$` that never close: text
            }
            index = text.index(after: index)
        }
        return representations
    }

    private func escaped(_ index: String.Index, in text: String) -> Bool {
        index > text.startIndex && text[text.index(before: index)] == "\\"
    }

    /// Start of the right terminator that closes `kind`, nil when there is none.
    private func closing(_ kind: MathRepresentation.Kind, from start: String.Index, in text: String) -> String.Index? {
        let end = kind.rightTerminator
        guard kind == .inlineEquation else {
            var from = start
            while let found = text.range(of: end, range: from..<text.endIndex) {
                if !escaped(found.lowerBound, in: text), found.lowerBound > start { return found.lowerBound }
                from = found.upperBound
            }
            return nil
        }
        guard start < text.endIndex, !text[start].isWhitespace else { return nil }
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if character == "\n" { return nil }
            if character == "$", !escaped(index, in: text) {
                // The next `$` closes or nothing does: in "$5, area $x^2$" the first `$` is a price.
                let after = text.index(after: index)
                let before = text[text.index(before: index)]
                return !before.isWhitespace && (after == text.endIndex || !text[after].isNumber) ? index : nil
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// `text` may be a substring; ranges are into it, as callers index it.
    private func offsetRange(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        let lower = self.text.index(self.text.startIndex, offsetBy: text.distance(from: text.startIndex, to: range.lowerBound))
        let upper = self.text.index(lower, offsetBy: text.distance(from: range.lowerBound, to: range.upperBound))
        return lower..<upper
    }
}

// MARK: - Placeholders

/// Math is swapped for a placeholder before cmark parses the text: cmark would otherwise eat the
/// backslash of `\{`, `\,` and `\\`, and read `*` and `_` inside it as emphasis. The LaTeX travels
/// hex-encoded between private-use characters, which no Markdown rule touches.
extension MathParser {
    public enum Segment: Hashable, Sendable {
        case text(String)
        case math(String, display: Bool)
    }

    static let inlineOpen: Character = "\u{E000}"
    static let displayOpen: Character = "\u{E002}"
    static let close: Character = "\u{E001}"

    public static func placeholder(_ latex: String, display: Bool) -> String {
        String(display ? displayOpen : inlineOpen) + latex.utf8.map { String(format: "%02x", $0) }.joined() + String(close)
    }

    /// The LaTeX of a span the parser found, without its terminators.
    public static func latex(of representation: MathRepresentation, in text: some StringProtocol) -> String {
        let kind = representation.kind
        let span = text[representation.range]
        return String(span.dropFirst(kind.leftTerminator.count).dropLast(kind.rightTerminator.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `text` with every math span replaced by its placeholder. Display math on lines of its own
    /// gets a display placeholder (a centred block); any other math is drawn inline.
    public static func protect(_ text: some StringProtocol) -> String {
        var out = String(text)
        for representation in MathParser(text: out).mathRepresentations.reversed() {
            let display = !representation.kind.inline && ownsItsLines(representation.range, in: out)
            out.replaceSubrange(representation.range,
                                with: placeholder(latex(of: representation, in: out), display: display))
        }
        return out
    }

    /// Only blanks between the line's start and `range`, and between `range` and the line's end.
    public static func ownsItsLines(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = text[..<range.lowerBound].reversed().prefix { $0 != "\n" }
        let after = text[range.upperBound...].prefix { $0 != "\n" }
        return before.allSatisfy { $0 == " " || $0 == "\t" } && after.allSatisfy(\.isWhitespace)
    }

    public static func segments(in text: String) -> [Segment] {
        guard text.contains(where: { $0 == inlineOpen || $0 == displayOpen }) else { return [.text(text)] }
        var out: [Segment] = []
        var plain = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == inlineOpen || character == displayOpen,
               let end = text[index...].firstIndex(of: close),
               let latex = decode(text[text.index(after: index)..<end]) {
                if !plain.isEmpty { out.append(.text(plain)); plain = "" }
                out.append(.math(latex, display: character == displayOpen))
                index = text.index(after: end)
            } else {
                plain.append(character)
                index = text.index(after: index)
            }
        }
        if !plain.isEmpty { out.append(.text(plain)) }
        return out
    }

    private static func decode(_ hex: Substring) -> String? {
        guard hex.utf8.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return String(bytes: bytes, encoding: .utf8)
    }
}

extension MathParser {
    public struct MathRepresentation: Sendable, Hashable {
        public var kind: Kind
        public var range: Range<String.Index>
    }
}

extension MathParser.MathRepresentation {
    public enum Kind: Hashable, Sendable, CaseIterable {
        /// An inline equation component.
        ///
        /// - Example: `$x^2$`
        case inlineEquation
        
        /// An inline equation component.
        ///
        /// - Example: `\(x^2\)`
        case inlineParenthesesEquation
        
        /// A TeX-style block equation.
        ///
        /// - Example: `$$x^2$$`.
        case texEquation
        
        /// A block equation.
        ///
        /// - Example: `\[x^2\]`
        case blockEquation
        
        /// A named equation component.
        ///
        /// - Example: `\begin{equation}x^2\end{equation}`
        case namedEquation
        
        /// A named equation component.
        ///
        /// - Example: `\begin{equation*}x^2\end{equation*}`
        case namedNoNumberEquation
        
        /// The component's left terminator.
        var leftTerminator: String {
            switch self {
            case .inlineEquation: return "$"
            case .inlineParenthesesEquation: return "\\("
            case .texEquation: return "$$"
            case .blockEquation: return "\\["
            case .namedEquation: return "\\begin{equation}"
            case .namedNoNumberEquation: return "\\begin{equation*}"
            }
        }
        
        /// The component's right terminator.
        var rightTerminator: String {
            switch self {
            case .inlineEquation: return "$"
            case .inlineParenthesesEquation: return "\\)"
            case .texEquation: return "$$"
            case .blockEquation: return "\\]"
            case .namedEquation: return "\\end{equation}"
            case .namedNoNumberEquation: return "\\end{equation*}"
            }
        }
        
        /// Whether or not this component is inline.
        public var inline: Bool {
            switch self {
            case .inlineEquation, .inlineParenthesesEquation: return true
            default: return false
            }
        }
        
        public static let allCases: [Kind] = [
            .namedNoNumberEquation,
            .namedEquation,
            .blockEquation,
            .texEquation,
            .inlineEquation,
            .inlineParenthesesEquation,
        ]
    }
}
