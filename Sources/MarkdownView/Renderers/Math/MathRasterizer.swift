//
//  MathRasterizer.swift
//  MarkdownView
//

import SwiftUI
#if canImport(SwiftMath) && canImport(UIKit)
import SwiftMath
import UIKit

/// LaTeX typeset by SwiftMath into an image, synchronously: the size is known the moment a view
/// asks, so a bubble's first frame already has its final height. Shared with renderers outside
/// this package (IMKit's streaming renderer draws the same images), so both look the same.
@_spi(MarkdownMath)
public enum MathRasterizer {
    public struct Figure: @unchecked Sendable {
        public let image: UIImage
        /// Above and below the baseline, in points: an inline figure sits `descent` below it.
        public let ascent: CGFloat
        public let descent: CGFloat
    }

    private final class Entry {
        let figure: Figure?
        init(_ figure: Figure?) { self.figure = figure }
    }

    nonisolated(unsafe) private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.totalCostLimit = 32 << 20 // bytes of bitmap
        return cache
    }()

    /// Math comes from whoever sent the message and is drawn on the main thread: a formula
    /// longer or larger than any real one shows its source instead (300 nested `\sqrt` take
    /// ~280 ms and lay out 5389 × 1199 pt).
    static let maxLength = 600
    static let maxSide: CGFloat = 4000

    /// nil when SwiftMath cannot typeset `latex` (an unknown command): show the source instead.
    /// `color` nil draws black for a template image, which SwiftUI tints with the text's style.
    public static func figure(_ latex: String, display: Bool, fontSize: CGFloat, color: UIColor? = nil) -> Figure? {
        let colorKey = color.map { "\($0.cgColor.components ?? [])" } ?? "template"
        let key = "\(display ? "D" : "I")|\(fontSize)|\(colorKey)|\(latex)" as NSString
        if let hit = cache.object(forKey: key) { return hit.figure }
        guard latex.utf8.count <= maxLength else { return nil }
        var math = MathImage(latex: latex, fontSize: fontSize, textColor: color ?? .black,
                             labelMode: display ? .display : .text, textAlignment: .left)
        let (error, image, layout) = math.asImage()
        var figure: Figure?
        if error == nil, let image, let layout, image.size.width > 0, image.size.height > 0,
           image.size.width <= maxSide, image.size.height <= maxSide {
            figure = Figure(image: color == nil ? image.withRenderingMode(.alwaysTemplate) : image,
                            ascent: layout.ascent, descent: layout.descent)
        }
        let cost = figure?.image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(Entry(figure), forKey: key, cost: cost)
        return figure
    }
}

/// An inline formula inside a text run: one U+FFFC carrying its LaTeX. `_MarkdownText` swaps it
/// for `Text(Image)`, so the formula wraps with the words around it and sits on their baseline.
enum MarkdownInlineMathAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "MarkdownView.inlineMath"
}

extension AttributedString {
    /// The run for one inline formula.
    static func inlineMath(_ latex: String) -> AttributedString {
        var run = AttributedString("\u{FFFC}")
        run[MarkdownInlineMathAttribute.self] = latex
        return run
    }

    var containsInlineMath: Bool {
        runs.contains { $0[MarkdownInlineMathAttribute.self] != nil }
    }
}

extension Text {
    /// `string` as one text, its inline formulas as images. A formula SwiftMath cannot typeset
    /// shows its source.
    static func withInlineMath(_ string: AttributedString, fontSize: CGFloat) -> Text {
        var text = Text(verbatim: "")
        var plain = AttributedString()
        for run in string.runs {
            guard let latex = run[MarkdownInlineMathAttribute.self] else {
                plain += AttributedString(string[run.range])
                continue
            }
            let formula: Text
            if let figure = MathRasterizer.figure(latex, display: false, fontSize: fontSize) {
                formula = Text(Image(uiImage: figure.image)).baselineOffset(-figure.descent)
            } else {
                formula = Text(verbatim: "$\(latex)$")
            }
            text = Text("\(text)\(Text(plain))\(formula)")
            plain = AttributedString()
        }
        return Text("\(text)\(Text(plain))")
    }
}
#endif
