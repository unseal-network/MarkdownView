import SwiftUI

extension View {
    /// Disable for untrusted chat/AI content. Raw HTML is shown as literal text instead
    /// of being loaded into a web view. Fenced HTML code blocks are unaffected.
    public func allowRawHTML(_ allowed: Bool) -> some View {
        transformEnvironment(\.markdownRendererConfiguration) { $0.allowsRawHTML = allowed }
    }

    /// Disable automatic image rendering for private chat to prevent remote tracking
    /// requests. Message attachments should use the host's authenticated media loader.
    public func allowImages(_ allowed: Bool) -> some View {
        transformEnvironment(\.markdownRendererConfiguration) { $0.allowsImages = allowed }
    }
}
