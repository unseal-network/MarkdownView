import SwiftUI

/// Animates per-character fade-in for newly arrived streaming text.
///
/// Characters at indices `newCharStart..<attributedText.characters.count` fade in
/// from transparent to opaque in a wave. Once the wave completes the view switches
/// to a static `_MarkdownText` so `TimelineView` stops firing.
struct StreamingRevealView: View {
    let attributedText: AttributedString
    /// Index of the first character that should animate in.
    let newCharStart: Int
    /// Timestamp when this reveal wave started.
    let revealStartDate: Date

    private let charsPerSecond: Double = 60
    private let fadeDuration: Double = 0.15

    @State private var animating: Bool = true

    private var newCharCount: Int {
        max(0, attributedText.characters.count - newCharStart)
    }

    private var totalDuration: Double {
        Double(newCharCount) / charsPerSecond + fadeDuration
    }

    var body: some View {
        Group {
            if animating && newCharCount > 0 {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(revealStartDate)
                    _MarkdownText(revealed(elapsed: elapsed))
                }
            } else {
                _MarkdownText(attributedText)
            }
        }
        .task(id: attributedText) {
            guard newCharCount > 0 else { return }
            animating = true
            let nanoseconds = UInt64((totalDuration + 0.05) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            animating = false
        }
    }

    /// Returns `attributedText` with in-progress characters set to a partial opacity.
    /// Characters fully revealed (alpha == 1) retain their natural foreground color.
    func revealed(elapsed: Double) -> AttributedString {
        var result = attributedText
        guard newCharStart < result.characters.count else { return result }

        var idx = result.index(result.startIndex, offsetByCharacters: newCharStart)
        for i in 0..<newCharCount {
            guard idx < result.endIndex else { break }
            let nextIdx = result.index(idx, offsetByCharacters: 1)
            let charRevealTime = Double(i) / charsPerSecond
            let alpha = max(0.0, min(1.0, (elapsed - charRevealTime) / fadeDuration))
            if alpha < 1.0 {
                result[idx..<nextIdx].foregroundColor = Color.primary.opacity(alpha)
            }
            idx = nextIdx
        }
        return result
    }
}
