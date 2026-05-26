# Streaming Reveal Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-character fade-in animation to `MarkdownView` for streaming LLM output via a single `.streamingReveal(isStreaming:)` modifier.

**Architecture:** When `isStreaming` is true, `MarkdownView` routes to a stateful `StreamingMarkdownView` that renders via `CmarkNodeVisitor`, extracts the resulting `AttributedString`, and hands it to `StreamingRevealView`. `StreamingRevealView` uses `TimelineView(.animation)` to interpolate per-character `foregroundColor` opacity on each display frame, creating a smooth fade-in wave. When the animation completes, a `.task` cancels the timeline and switches to a static `_MarkdownText`.

**Tech Stack:** Swift, SwiftUI, `swift-markdown` (`Markup`, `Document`, `ParseOptions`), `AttributedString`, `TimelineView`

---

## File Map

**Create:**
- `Sources/MarkdownView/Streaming/StreamingRevealView.swift` — per-char animation view
- `Sources/MarkdownView/Streaming/StreamingMarkdownView.swift` — stateful container tracking prev/new char counts
- `Sources/MarkdownView/Modifiers/StreamingRevealModifier.swift` — public `.streamingReveal()` modifier

**Modify:**
- `Sources/MarkdownView/Configurations/MarkdownRendererConfiguration.swift` — add `isStreaming: Bool`
- `Sources/MarkdownView/MarkdownView.swift` — route to `StreamingMarkdownView` when streaming
- `UnsealAgent/Views/MarkdownViewRenderer.swift` (app) — pass `isStreaming` into `_MarkdownBody`
- `UnsealUI/Views/BubbleMessageView.swift` (app) — apply `.streamingReveal()`, remove `TimelineView` cursor

---

## Task 1: Add `isStreaming` to configuration

**Files:**
- Modify: `Sources/MarkdownView/Configurations/MarkdownRendererConfiguration.swift`

- [ ] **Add the flag**

  Replace the struct body to add `isStreaming`:

  ```swift
  struct MarkdownRendererConfiguration: Equatable, AllowingModifyThroughKeyPath, Sendable {
      var preferredBaseURL: URL?
      var componentSpacing: CGFloat = 8
      var math: Math = Math()
      var linkTintColor: Color = .accentColor
      var inlineCodeTintColor: Color = .accentColor
      var blockQuoteTintColor: Color = .accentColor
      var listConfiguration: MarkdownListConfiguration = MarkdownListConfiguration()
      var allowedImageRenderers: Set<String> = ["https", "http"]
      var allowedBlockDirectiveRenderers: Set<String> = []
      var isStreaming: Bool = false
  }
  ```

- [ ] **Build the library to verify it compiles**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -5
  ```
  Expected: `Build complete!`

- [ ] **Commit**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView
  git add Sources/MarkdownView/Configurations/MarkdownRendererConfiguration.swift
  git commit -m "feat: add isStreaming flag to MarkdownRendererConfiguration"
  ```

---

## Task 2: Add public `.streamingReveal()` modifier

**Files:**
- Create: `Sources/MarkdownView/Modifiers/StreamingRevealModifier.swift`

- [ ] **Create the modifier file**

  ```swift
  // Sources/MarkdownView/Modifiers/StreamingRevealModifier.swift
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
  ```

- [ ] **Build to verify**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -5
  ```
  Expected: `Build complete!`

- [ ] **Commit**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView
  git add Sources/MarkdownView/Modifiers/StreamingRevealModifier.swift
  git commit -m "feat: add public streamingReveal() modifier"
  ```

---

## Task 3: Create `StreamingRevealView`

**Files:**
- Create: `Sources/MarkdownView/Streaming/StreamingRevealView.swift`

- [ ] **Create the Streaming directory and view**

  ```swift
  // Sources/MarkdownView/Streaming/StreamingRevealView.swift
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
              try? await Task.sleep(for: .seconds(totalDuration + 0.05))
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
  ```

- [ ] **Build to verify**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -5
  ```
  Expected: `Build complete!`

- [ ] **Commit**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView
  git add Sources/MarkdownView/Streaming/StreamingRevealView.swift
  git commit -m "feat: add StreamingRevealView with per-char fade animation"
  ```

---

## Task 4: Create `StreamingMarkdownView`

**Files:**
- Create: `Sources/MarkdownView/Streaming/StreamingMarkdownView.swift`

- [ ] **Create the stateful container**

  ```swift
  // Sources/MarkdownView/Streaming/StreamingMarkdownView.swift
  import SwiftUI
  import Markdown

  /// Stateful wrapper that drives the streaming render pipeline.
  ///
  /// On each content change it renders via `CmarkNodeVisitor`, extracts the
  /// resulting `AttributedString`, computes how many characters are new, and
  /// hands the result to `StreamingRevealView`.
  ///
  /// For mixed content (code blocks, images, tables) where `CmarkNodeVisitor`
  /// returns an `AnyView` rather than an `AttributedString`, rendering falls back
  /// to `CmarkFirstMarkdownViewRenderer` with no animation.
  @MainActor
  struct StreamingMarkdownView: View {
      let content: MarkdownContent
      let configuration: MarkdownRendererConfiguration

      @State private var attributedString: AttributedString? = nil
      @State private var previousCharCount: Int = 0
      @State private var revealStartDate: Date = .now

      var body: some View {
          Group {
              if let attrStr = attributedString {
                  StreamingRevealView(
                      attributedText: attrStr,
                      newCharStart: previousCharCount,
                      revealStartDate: revealStartDate
                  )
              } else {
                  // Fallback: mixed content or initial render before task fires.
              // Use nonStreamingConfiguration to avoid polluting the renderer cache.
                  CmarkFirstMarkdownViewRenderer()
                      .makeBody(content: content, configuration: nonStreamingConfiguration)
              }
          }
          .environment(\.markdownRendererConfiguration, configuration)
          .task(id: content) {
              updateContent()
          }
      }

      private func updateContent() {
          var parseOptions = ParseOptions()
          if !configuration.allowedBlockDirectiveRenderers.isEmpty {
              parseOptions.insert(.parseBlockDirectives)
          }

          var visitor = CmarkNodeVisitor(configuration: configuration)
          let document = content.parse(options: parseOptions)
          guard let newAttrStr = visitor.visit(document).asAttributedString else {
              // Mixed content: clear attributedString so body falls back to CmarkFirstMarkdownViewRenderer
              attributedString = nil
              return
          }

          let newCount = newAttrStr.characters.count
          let prevCount = attributedString?.characters.count ?? 0

          if newCount > prevCount, prevCount > 0 {
              // New characters arrived — start a reveal wave from where we left off
              previousCharCount = prevCount
              revealStartDate = .now
          } else {
              // First render or content replaced: show all chars as already revealed
              previousCharCount = newCount
          }

          attributedString = newAttrStr
      }

      /// Configuration with isStreaming disabled, used for the mixed-content fallback
      /// so CmarkFirstMarkdownViewRenderer's cache is not polluted with streaming renders.
      private var nonStreamingConfiguration: MarkdownRendererConfiguration {
          var c = configuration
          c.isStreaming = false
          return c
      }
  }
  ```

- [ ] **Build to verify**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -5
  ```
  Expected: `Build complete!`

- [ ] **Commit**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView
  git add Sources/MarkdownView/Streaming/StreamingMarkdownView.swift
  git commit -m "feat: add StreamingMarkdownView stateful container"
  ```

---

## Task 5: Wire `StreamingMarkdownView` into `MarkdownView`

**Files:**
- Modify: `Sources/MarkdownView/MarkdownView.swift`

- [ ] **Add streaming branch to `_renderedBody`**

  Replace the `_renderedBody` computed property:

  ```swift
  @ViewBuilder
  private var _renderedBody: some View {
      if configuration.isStreaming {
          StreamingMarkdownView(content: content, configuration: configuration)
      } else if configuration.math.shouldRender {
          MathFirstMarkdownViewRenderer()
              .makeBody(content: content, configuration: configuration)
      } else {
          CmarkFirstMarkdownViewRenderer()
              .makeBody(content: content, configuration: configuration)
      }
  }
  ```

- [ ] **Build to verify**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -5
  ```
  Expected: `Build complete!`

- [ ] **Commit**

  ```bash
  cd /Users/jelf/Projects/work/MarkdownView
  git add Sources/MarkdownView/MarkdownView.swift
  git commit -m "feat: route to StreamingMarkdownView when isStreaming"
  ```

---

## Task 6: Update app-side integration

**Files:**
- Modify: `UnsealAgent/Views/MarkdownViewRenderer.swift`
- Modify: `UnsealUI/Views/BubbleMessageView.swift`

- [ ] **Add `isStreaming` parameter to `_MarkdownBody` and `MarkdownRenderView`**

  In `UnsealAgent/Views/MarkdownViewRenderer.swift`, update `_MarkdownBody`:

  ```swift
  struct _MarkdownBody: View {
      let text: String
      let isUserMessage: Bool
      var isStreaming: Bool = false
      // ...
      var body: some View {
          MarkdownView(text)
              .streamingReveal(isStreaming: isStreaming)
              // ... rest of modifiers unchanged ...
      }
  }
  ```

  Update `MarkdownRenderView`:

  ```swift
  public struct MarkdownRenderView: View {
      public let content: String
      public let isUserMessage: Bool
      public var isStreaming: Bool = false

      public var body: some View {
          _MarkdownBody(text: content, isUserMessage: isUserMessage, isStreaming: isStreaming)
      }

      public init(content: String, isUserMessage: Bool, isStreaming: Bool = false) {
          self.content = content
          self.isUserMessage = isUserMessage
          self.isStreaming = isStreaming
      }
  }
  ```

- [ ] **Update `BubbleMessageView.partView` to use the new API**

  In `UnsealUI/Views/BubbleMessageView.swift`, replace the `textPart` branch in `partView`:

  ```swift
  } else if let textPart = part as? TextUIPart {
      let isStreamingText = isStreaming && isLast && textPart.state == .streaming
      MarkdownRenderView(content: textPart.text, isUserMessage: false, isStreaming: isStreamingText)
          .padding(.top, 8)
  ```

  This removes the `TimelineView` cursor approach entirely. The streaming animation is now handled inside the library.

- [ ] **Build the app to verify**

  In Xcode, build the `UnsealAgent` scheme (or run `swift build` from the project root).  
  Expected: no compile errors.

- [ ] **Commit**

  ```bash
  cd /Users/jelf/Projects/work/unseal-agent-ios
  git add UnsealAgent/Views/MarkdownViewRenderer.swift UnsealUI/Views/BubbleMessageView.swift
  git commit -m "feat: integrate streamingReveal into BubbleMessageView"
  ```

---

## Task 7: Manual visual test

- [ ] **Open the streaming demo preview in Xcode**

  Open `BubbleMessageView.swift` and run the `#Preview("Streaming Demo")` canvas. Verify:
  1. Characters appear one by one with a smooth fade-in as the demo plays
  2. Completed text renders as normal markdown (bold, italic, links correctly styled)
  3. The `StreamingCursor` in the standalone case (tool running) still blinks correctly
  4. After streaming ends, the view shows normal static markdown with no lingering animation

- [ ] **Test with a message that contains a code block**

  Add a temporary `TextUIPart` with markdown like `"Here is code:\n\`\`\`swift\nlet x = 1\n\`\`\`"` to `StreamingDemoView.phase2`. Verify the code block renders correctly (falls back to `CmarkFirstMarkdownViewRenderer`) while the text before it animated in.

- [ ] **Check no performance regression**

  With Instruments or Xcode's CPU gauge, stream a long response (~500 chars). CPU usage should be comparable to before the change (the animation adds `TimelineView` overhead only during the brief reveal window per chunk).
