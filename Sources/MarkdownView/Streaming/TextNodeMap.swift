import Markdown

/// Pre-computed map of every visible text node's global character offset.
///
/// Built from a lightweight AST walk before the render pass. The offsets
/// follow document order so the trailing gradient knows which characters
/// are near the end regardless of block type (paragraph, heading, etc.).
struct TextNodeMap: Equatable, Sendable {
    let totalVisibleChars: Int
    let offsets: [String: Int]
    /// Visible-character offset at which each top-level block starts, in document order.
    /// Lets streaming tell which blocks the reveal gradient can still touch.
    var blockStarts: [Int] = []

    static func build(from document: Document) -> TextNodeMap {
        var offset = 0
        var offsets: [String: Int] = [:]
        var blockStarts: [Int] = []

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
            } else if let codeBlock = markup as? CodeBlock {
                if let loc = codeBlock.range?.lowerBound {
                    offsets["\(loc.line):\(loc.column)"] = offset
                }
                offset += codeBlock.code.count
            } else {
                for child in markup.children {
                    walk(child)
                }
            }
        }

        for block in document.children {
            blockStarts.append(offset)
            walk(block)
        }
        return TextNodeMap(totalVisibleChars: offset, offsets: offsets, blockStarts: blockStarts)
    }
}
