import SwiftUI

extension View {
    /// Enables per-character streaming reveal animation.
    /// - Parameter isStreaming: Pass `true` while the LLM is streaming output.
    /// - Parameter haptics: Explicit opt-in. Disabled by default for high-frequency chat.
    public func streamingReveal(isStreaming: Bool, haptics: Bool = false) -> some View {
        transformEnvironment(\.markdownRendererConfiguration) { config in
            config.isStreaming = isStreaming
            config.streamingHapticsEnabled = haptics
        }
    }
}
