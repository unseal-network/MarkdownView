import SwiftUI

/// Wraps a document-level block during streaming, animating it in
/// with a subtle upward float + fade on first appearance.
struct StreamingBlockWrapper: View {
    let content: MarkdownNodeView
    @State private var appeared = false

    var body: some View {
        content
            .offset(y: appeared ? 0 : 6)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
    }
}
