import SwiftUI

extension View {
    /// Enables per-character streaming reveal animation.
    /// - Parameter isStreaming: Pass `true` while the LLM is streaming output.
    public func streamingReveal(isStreaming: Bool) -> some View {
        transformEnvironment(\.markdownRendererConfiguration) { config in
            config.isStreaming = isStreaming
        }
    }
}
