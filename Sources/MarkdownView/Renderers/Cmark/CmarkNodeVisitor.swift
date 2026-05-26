//
//  CmarkNodeVisitor.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/4/12.
//

import SwiftUI
import Markdown

@MainActor
@preconcurrency
struct CmarkNodeVisitor: @preconcurrency MarkupVisitor {
    var configuration: MarkdownRendererConfiguration
    
    init(configuration: MarkdownRendererConfiguration) {
        self.configuration = configuration
    }
    
    func makeBody(for markup: any Markup) -> some View {
        var visitor = self
        return visitor
            .visit(markup)
            .environment(\.markdownRendererConfiguration, configuration)
    }

    func visitDocument(_ document: Document) -> MarkdownNodeView {
        var renderer = self
        if configuration.isStreaming {
            let nodeViews = document.children.map { child in
                let view = renderer.visit(child)
                return MarkdownNodeView { StreamingBlockWrapper(content: view) }
            }
            return MarkdownNodeView(nodeViews, layoutPolicy: .linebreak)
        }
        let nodeViews = document.children.map { renderer.visit($0) }
        return MarkdownNodeView(nodeViews, layoutPolicy: .linebreak)
    }
    
    func defaultVisit(_ markup: Markdown.Markup) -> MarkdownNodeView {
        descendInto(markup)
    }
    
    func descendInto(_ markup: any Markup) -> MarkdownNodeView {
        var nodeViews = [MarkdownNodeView]()
        for child in markup.children {
            var renderer = self
            let nodeView = renderer.visit(child)
            nodeViews.append(nodeView)
        }
        return MarkdownNodeView(nodeViews)
    }
    
    func visitText(_ text: Markdown.Text) -> MarkdownNodeView {
        if configuration.math.shouldRender {
            return InlineMathOrText(text: text.plainText)
                .makeBody(configuration: configuration)
        }
        guard let map = configuration.streamingTextNodeMap,
              let loc = text.range?.lowerBound,
              let globalOffset = map.offsets["\(loc.line):\(loc.column)"] else {
            return MarkdownNodeView(text.plainText)
        }
        return MarkdownNodeView(
            applyStreamingGradient(to: text.plainText, globalOffset: globalOffset, map: map)
        )
    }
    
    func visitBlockDirective(_ blockDirective: BlockDirective) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownBlockDirective(blockDirective: blockDirective)
        }
    }
    
    func visitBlockQuote(_ blockQuote: BlockQuote) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownBlockQuote(blockQuote: blockQuote)
        }
    }
    
    func visitSoftBreak(_ softBreak: SoftBreak) -> MarkdownNodeView {
        MarkdownNodeView(" ")
    }
    
    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> MarkdownNodeView {
        MarkdownNodeView {
            Divider()
        }
    }
    
    func visitLineBreak(_ lineBreak: LineBreak) -> MarkdownNodeView {
        MarkdownNodeView("\n")
    }
    
    func visitInlineCode(_ inlineCode: InlineCode) -> MarkdownNodeView {
        var attributedString = AttributedString(stringLiteral: inlineCode.code)
        attributedString.foregroundColor = configuration.inlineCodeTintColor
        attributedString.backgroundColor = configuration.inlineCodeTintColor.opacity(0.1)
        if let map = configuration.streamingTextNodeMap,
           let loc = inlineCode.range?.lowerBound,
           let globalOffset = map.offsets["\(loc.line):\(loc.column)"] {
            attributedString = applyStreamingGradient(to: attributedString, globalOffset: globalOffset, map: map)
        }
        return MarkdownNodeView(attributedString)
    }
    
    func visitInlineHTML(_ inlineHTML: InlineHTML) -> MarkdownNodeView {
        MarkdownNodeView(
            AttributedString(
                inlineHTML.rawHTML,
                attributes: AttributeContainer().isHTML(true)
            )
        )
    }
    
    func visitImage(_ image: Markdown.Image) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownImage(image: image)
        }
    }
    
    func visitCodeBlock(_ codeBlock: CodeBlock) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownStyledCodeBlock(
                configuration: CodeBlockStyleConfiguration(
                    language: codeBlock.language,
                    code: codeBlock.code
                )
            )
        }
    }
    
    func visitHTMLBlock(_ html: HTMLBlock) -> MarkdownNodeView {
        MarkdownNodeView {
            HTMLBlockView(html: html.rawHTML)
        }
    }
    
    func visitListItem(_ listItem: ListItem) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownListItem(listItem: listItem)
        }
    }
    
    func visitOrderedList(_ orderedList: OrderedList) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownList(listItemsContainer: orderedList)
        }
    }
    
    func visitUnorderedList(_ unorderedList: UnorderedList) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownList(listItemsContainer: unorderedList)
        }
    }
    
    func visitTable(_ table: Markdown.Table) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownTable(table: table)
        }
    }
    
    func visitTableHead(_ head: Markdown.Table.Head) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownTableRow(
                rowIndex: 0,
                cells: Array(head.cells)
            )
        }
    }
    
    func visitTableBody(_ body: Markdown.Table.Body) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownTableBody(tableBody: body)
        }
    }
    
    func visitTableRow(_ row: Markdown.Table.Row) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownTableRow(
                rowIndex: row.indexInParent + 1 /* header */,
                cells: Array(row.cells)
            )
        }
    }
    
    func visitTableCell(_ cell: Markdown.Table.Cell) -> MarkdownNodeView {
        var cellViews = [MarkdownNodeView]()
        for child in cell.children {
            var renderer = CmarkNodeVisitor(configuration: configuration)
            let cellView = renderer.visit(child)
            cellViews.append(cellView)
        }
        return MarkdownNodeView(
            cellViews,
            alignment: cell.horizontalAlignment
        )
    }
    
    func visitParagraph(_ paragraph: Paragraph) -> MarkdownNodeView {
        defaultVisit(paragraph)
    }
    
    func visitHeading(_ heading: Heading) -> MarkdownNodeView {
        MarkdownNodeView {
            MarkdownHeading(heading: heading)
        }
    }
    
    func visitEmphasis(_ emphasis: Markdown.Emphasis) -> MarkdownNodeView {
        var attributedString = AttributedString()
        for child in emphasis.children {
            var renderer = self
            guard let text = renderer.visit(child).asAttributedString else { continue }
            let intent = text.inlinePresentationIntent ?? []
            attributedString += text.mergingAttributes(
                AttributeContainer()
                    .inlinePresentationIntent(intent.union(.emphasized))
            )
        }
        return MarkdownNodeView(attributedString)
    }
    
    func visitStrong(_ strong: Strong) -> MarkdownNodeView {
        var attributedString = AttributedString()
        for child in strong.children {
            var renderer = self
            guard let text = renderer.visit(child).asAttributedString else { continue }
            let intent = text.inlinePresentationIntent ?? []
            attributedString += text.mergingAttributes(
                AttributeContainer()
                    .inlinePresentationIntent(intent.union(.stronglyEmphasized))
            )
        }
        return MarkdownNodeView(attributedString)
    }
    
    func visitStrikethrough(_ strikethrough: Strikethrough) -> MarkdownNodeView {
        var attributedString = AttributedString()
        for child in strikethrough.children {
            var renderer = self
            guard let text = renderer.visit(child).asAttributedString else { continue }
            let intent = text.inlinePresentationIntent ?? []
            attributedString += text.mergingAttributes(
                AttributeContainer()
                    .inlinePresentationIntent(intent.union(.strikethrough))
            )
        }
        return MarkdownNodeView(attributedString)
    }
    
    // MARK: - Streaming gradient

    private func applyStreamingGradient(to text: String, globalOffset: Int, map: TextNodeMap) -> AttributedString {
        applyStreamingGradient(to: AttributedString(text), globalOffset: globalOffset, map: map)
    }

    /// Three-zone gradient based on `revealedCount`:
    ///   • before `revealedCount - windowSize` → fully visible
    ///   • `revealedCount - windowSize ..< revealedCount` → gradient (ease-in)
    ///   • `>= revealedCount` → fully transparent (hidden)
    private func applyStreamingGradient(to attributed: AttributedString, globalOffset: Int, map: TextNodeMap) -> AttributedString {
        let revealedCount = configuration.streamingRevealedCount
        let windowSize = configuration.streamingWindowSize
        let gradientStart = revealedCount - windowSize

        let nodeStart = globalOffset
        let nodeEnd = globalOffset + attributed.characters.count - 1

        // Entire node is before gradient → fully visible, skip
        if nodeEnd < gradientStart { return attributed }

        var result = attributed
        let loopStart = max(0, gradientStart - nodeStart)
        var idx = result.index(result.startIndex, offsetByCharacters: loopStart)
        for i in loopStart..<result.characters.count {
            guard idx < result.endIndex else { break }
            let nextIdx = result.index(idx, offsetByCharacters: 1)
            let globalIdx = nodeStart + i

            if globalIdx >= revealedCount {
                // Hidden zone — set remaining chars transparent in bulk
                result[idx...].foregroundColor = Color.primary.opacity(0)
                break
            }
            // Gradient zone
            let distFromReveal = revealedCount - 1 - globalIdx
            if distFromReveal < windowSize {
                let progress = Double(distFromReveal + 1) / Double(windowSize + 1)
                let alpha = progress * progress
                let existing = result[idx..<nextIdx].foregroundColor ?? Color.primary
                result[idx..<nextIdx].foregroundColor = existing.opacity(alpha)
            }
            idx = nextIdx
        }
        return result
    }

    mutating func visitLink(_ link: Markdown.Link) -> MarkdownNodeView {
        guard let destination = link.destination,
              let url = URL(string: destination)
        else { return descendInto(link) }
        
        let nodeView = descendInto(link)
        return if let attributedString = nodeView.asAttributedString {
            MarkdownNodeView(
                attributedString.mergingAttributes(
                    AttributeContainer()
                        .link(url)
                        .foregroundColor(configuration.linkTintColor)
                )
            )
        } else {
             MarkdownNodeView {
                Link(destination: url) {
                    nodeView
                }
                .foregroundStyle(configuration.linkTintColor)
            }
        }
    }
}
