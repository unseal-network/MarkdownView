//
//  MathBlockDirectiveRenderer.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/4/12.
//

import Foundation
import SwiftUI

struct MathBlockDirectiveRenderer: BlockDirectiveRenderer {
    func makeBody(configuration: Configuration) -> some View {
        if let identifier = UUID(uuidString: configuration.arguments[0].value) {
            DisplayMath(mathIdentifier: identifier)
        } else {
            EmptyView()
        }
    }
}

/// A display formula, centred; narrower than its width, it scales down to fit rather than
/// scrolling (the streaming renderer does the same, so a bubble does not change when it ends).
fileprivate struct DisplayMath: View {
    var mathIdentifier: UUID
    @Environment(\.markdownRendererConfiguration.math) private var math
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    private var latexMath: String? {
        math.displayMathStorage?[mathIdentifier]
    }

    var body: some View {
        if let latexMath {
            #if canImport(SwiftMath) && canImport(UIKit)
            if let figure = MathRasterizer.figure(latexMath, display: true, fontSize: fontSize) {
                Image(uiImage: figure.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: figure.image.size.width)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(latexMath)
            } else {
                source(latexMath)
            }
            #else
            source(latexMath)
            #endif
        }
    }

    private func source(_ latex: String) -> some View {
        Text(verbatim: "$$\(latex)$$")
            .font(.system(.callout, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
