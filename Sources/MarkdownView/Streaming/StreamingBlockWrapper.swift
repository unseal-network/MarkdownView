import SwiftUI

/// Wraps a document-level block during streaming, fading it in on first appearance.
///
/// No positional float: in a chat the whole timeline is already scrolling to follow the reply,
/// and a block drifting up on its own spring moves against its neighbours (reads as shaking).
struct StreamingBlockWrapper: View {
    let content: MarkdownNodeView
    @State private var appeared = false

    var body: some View {
        content
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.22)) { appeared = true }
            }
    }
}
