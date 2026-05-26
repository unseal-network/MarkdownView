import Markdown

/// Pre-computed map of every visible text node's global character offset.
///
/// Built from a lightweight AST walk before the render pass. The offsets
/// follow document order so the trailing gradient knows which characters
/// are near the end regardless of block type (paragraph, heading, etc.).
struct TextNodeMap: Equatable, Sendable {
    let totalVisibleChars: Int
    let offsets: [String: Int]

    static func build(from document: Document) -> TextNodeMap {
        var offset = 0
        var offsets: [String: Int] = [:]

        func walk(_ markup: any Markup) {
            if let text = markup as? Markdown.Text {
                if let loc = text.range?.lowerBound {
                    offsets["\(loc.line):\(loc.column)"] = offset
                }
                offset += text.plainText.count
            } else if markup is SoftBreak {
                offset += 1
            } else if markup is LineBreak {
                offset += 1
            } else if let code = markup as? InlineCode {
                if let loc = code.range?.lowerBound {
                    offsets["\(loc.line):\(loc.column)"] = offset
                }
                offset += code.code.count
            } else {
                for child in markup.children {
                    walk(child)
                }
            }
        }

        walk(document)
        return TextNodeMap(totalVisibleChars: offset, offsets: offsets)
    }
}
