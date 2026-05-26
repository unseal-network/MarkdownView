import SwiftUI

/// Animates per-character fade-in for streaming text using a continuous wave.
///
/// The wave advances at `charsPerSecond` from `revealStartDate`. Characters at
/// index `newCharStart + i` become visible when the wave reaches them, then fade
/// in over `fadeDuration`. Because `revealStartDate` is fixed for the session,
/// newly-appended characters are naturally picked up as `attributedText` grows.
struct StreamingRevealView: View {
    let attributedText: AttributedString
    let newCharStart: Int
    let revealStartDate: Date

    private let charsPerSecond: Double = 12
    private let fadeDuration: Double = 1.0

    private var newCharCount: Int {
        max(0, attributedText.characters.count - newCharStart)
    }

    private var totalDuration: Double {
        Double(newCharCount) / charsPerSecond + fadeDuration
    }

    var body: some View {
        if newCharCount == 0 {
            _MarkdownText(attributedText)
        } else {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(revealStartDate)
                if elapsed >= totalDuration {
                    _MarkdownText(attributedText)
                } else {
                    _MarkdownText(revealed(elapsed: elapsed))
                }
            }
        }
    }

    /// Returns `attributedText` with new characters at their current animation opacity.
    func revealed(elapsed: Double) -> AttributedString {
        var result = attributedText
        guard newCharStart < result.characters.count else { return result }

        var idx = result.index(result.startIndex, offsetByCharacters: newCharStart)
        for i in 0..<newCharCount {
            guard idx < result.endIndex else { break }
            let nextIdx = result.index(idx, offsetByCharacters: 1)
            let charRevealTime = Double(i) / charsPerSecond

            if elapsed < charRevealTime {
                result[idx...].foregroundColor = Color.primary.opacity(0)
                break
            }

            let alpha = max(0.0, min(1.0, (elapsed - charRevealTime) / fadeDuration))
            if alpha < 1.0 {
                let existingColor = result[idx..<nextIdx].foregroundColor ?? Color.primary
                result[idx..<nextIdx].foregroundColor = existingColor.opacity(alpha)
            }
            idx = nextIdx
        }
        return result
    }
}
