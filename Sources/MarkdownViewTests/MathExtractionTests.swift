//
//  MathExtractionTests.swift
//  MarkdownView
//
//  Created by LiYanan2004 on 2025/4/9.
//

import Testing
@_spi(MarkdownMath) import MarkdownView

@MainActor
struct MathExtractionTests {
    struct MathExtractionTestConfiguration: Sendable {
        var plainText: String
        var extractedMath: [String]
    }
    
    @Test(
        arguments: [
            MathExtractionTestConfiguration(
                plainText: #"delimiters to show math inline: $\sqrt{3x-1}+(1+x)^2$"#,
                extractedMath: [#"$\sqrt{3x-1}+(1+x)^2$"#]
            ),
            MathExtractionTestConfiguration(
                plainText: #"""
                **The Cauchy-Schwarz Inequality**
                $$\left( \sum_{k=1}^n a_k b_k \right)^2 \leq \left( \sum_{k=1}^n a_k^2 \right) \left( \sum_{k=1}^n b_k^2 \right)$$
                """#,
                extractedMath: [#"$$\left( \sum_{k=1}^n a_k b_k \right)^2 \leq \left( \sum_{k=1}^n a_k^2 \right) \left( \sum_{k=1}^n b_k^2 \right)$$"#]
            ),
            MathExtractionTestConfiguration(
                plainText: #"\( G_{\mu\nu} \): Einstein tensor (spacetime curvature)"#,
                extractedMath: [#"\( G_{\mu\nu} \)"#]
            ),
            MathExtractionTestConfiguration(
                plainText: #"\[ \hat{H}\psi = E\psi \quad \text{where} \quad \hat{H} = -\frac{\hbar^2}{2m}\nabla^2 + V(\mathbf{r}) \]"#,
                extractedMath: [#"\[ \hat{H}\psi = E\psi \quad \text{where} \quad \hat{H} = -\frac{\hbar^2}{2m}\nabla^2 + V(\mathbf{r}) \]"#]
            ),
            // Chat text is full of prices: `$` opens only before a non-space, closes only after a
            // non-space and not before a digit (pandoc's rule).
            MathExtractionTestConfiguration(plainText: "It costs $5 and $10 today", extractedMath: []),
            MathExtractionTestConfiguration(plainText: "between $ 1 and 2 $", extractedMath: []),
            MathExtractionTestConfiguration(plainText: "$a$5", extractedMath: []),
            MathExtractionTestConfiguration(plainText: "paid $5, area $x^2$", extractedMath: ["$x^2$"]),
            MathExtractionTestConfiguration(plainText: "$x$ and $y$", extractedMath: ["$x$", "$y$"]),
            MathExtractionTestConfiguration(plainText: #"\$x$ is a literal dollar"#, extractedMath: []),
            MathExtractionTestConfiguration(plainText: "$a\n\nb$", extractedMath: []),
            MathExtractionTestConfiguration(plainText: "unclosed $x and more", extractedMath: []),
            MathExtractionTestConfiguration(plainText: "$$a$$ then $b$", extractedMath: ["$$a$$", "$b$"]),
            MathExtractionTestConfiguration(plainText: #"$$\text{if $x$}$$"#, extractedMath: [#"$$\text{if $x$}$$"#]),
            MathExtractionTestConfiguration(plainText: "$$\nx\n$$", extractedMath: ["$$\nx\n$$"]),
        ]
    )
    func testMathExtractionCase(
        _ configuration: MathExtractionTestConfiguration
    ) async throws {
        let parser = MathParser(text: configuration.plainText)
        let extractedMath = parser.mathRepresentations
            .map(\.range)
            .map { String(configuration.plainText[$0]) }
        #expect(extractedMath == configuration.extractedMath)
    }

    /// Math is swapped for a placeholder before cmark sees it, so `\{`, `\\`, `*` and `_` inside it
    /// survive; the placeholder must come back out exactly, next to the text around it.
    @Test func placeholderRoundTrip() {
        let latex = #"\{a_1 * b_2\} \\ x"#
        let text = "a " + MathParser.placeholder(latex, display: false) + " b"
        #expect(MathParser.segments(in: text) == [.text("a "), .math(latex, display: false), .text(" b")])
        #expect(MathParser.segments(in: "plain") == [.text("plain")])
        let display = MathParser.placeholder("x", display: true)
        #expect(MathParser.segments(in: display) == [.math("x", display: true)])
    }
}
