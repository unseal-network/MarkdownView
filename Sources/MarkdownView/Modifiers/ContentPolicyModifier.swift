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

    /// The URL schemes images may load from (by default `https` and `http`); others show their
    /// placeholder. Chat content: `["https"]`.
    public func imageURLSchemes(_ schemes: Set<String>) -> some View {
        transformEnvironment(\.markdownRendererConfiguration) { $0.allowedImageRenderers = schemes }
    }
}
