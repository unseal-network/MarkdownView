# Streaming Reveal Animation — Design Spec

**Date:** 2026-05-25  
**Scope:** Fork of `LiYanan2004/MarkdownView`

---

## Goal

Add per-character fade-in animation for streaming markdown content. Characters appear one by one with a smooth opacity transition as text arrives from the LLM.

---

## Architecture

### Public API

A single new modifier on `MarkdownView`:

```swift
MarkdownView(text)
    .streamingReveal(isStreaming: true)
```

No caller-side state needed. The library manages reveal state internally.

### Internal Components

**`StreamingRevealContainer`** (new, stateful `View`)  
Wraps the render pipeline when streaming is enabled. Tracks:
- `previousVisibleCharCount: Int` — visible char count from the last render
- `revealStartDate: Date` — timestamp when the latest reveal wave began

When `MarkdownContent` changes and the new visible char count exceeds the previous, it records the new `revealStartDate` and old char count, then hands both to `StreamingRevealView`.

**`StreamingRevealView`** (new)  
Receives the fully-rendered `AttributedString` (natural colors, all formatting intact) plus `newCharStart: Int` and `revealStartDate: Date`.

Uses `TimelineView(.animation)` (display refresh rate). Each frame:
1. Compute `elapsed = now - revealStartDate`
2. For each char `i` in range `newCharStart..<total`:
   - `charRevealTime = Double(i - newCharStart) / charsPerSecond` (default 60)
   - `alpha = clamp((elapsed - charRevealTime) / fadeDuration, 0, 1)` (fadeDuration = 0.15s)
   - If `alpha < 1.0`: set `foregroundColor = Color.primary.opacity(alpha)` on that character
3. Stop `TimelineView` once all chars reach alpha = 1.0

**`CmarkFirstMarkdownViewRenderer`** (modified)  
- When `configuration.isStreaming == true`: skip cache
- After rendering, extract `AttributedString` from `MarkdownNodeView`
- Route to `StreamingRevealContainer` instead of returning the view directly

**`MarkdownRendererConfiguration`** (modified)  
Add: `var isStreaming: Bool = false`

---

## Content Type Handling

| Content | Animation |
|---|---|
| Paragraph / inline text | Per-character fade (via `AttributedString`) |
| Headings | Per-character fade |
| Bold / italic / strikethrough | Per-character fade (formatting preserved) |
| Links | Per-character fade (brief color override during fade, imperceptible) |
| Code blocks | Whole-block fade-in (`.transition(.opacity)`) |
| Tables / images | Whole-block fade-in |

Mixed content (e.g. paragraph + code block) → text portion fades per-char, code block fades as a unit.

---

## Caller Integration (main app)

In `_MarkdownBody` (in `MarkdownViewRenderer.swift`):

```swift
MarkdownView(text)
    .streamingReveal(isStreaming: isStreaming)
```

Pass `isStreaming: Bool` down from `BubbleMessageView` via `_MarkdownBody`.

Remove the current `TimelineView` cursor hack in `BubbleMessageView.partView` once this is in place.

---

## Constraints

- `AttributedString` foreground color changes are not interpolated by SwiftUI — smooth animation comes from rapid frame-by-frame updates via `TimelineView(.animation)`.
- Link foreground colors briefly display as `Color.primary.opacity(alpha)` during fade (≤150ms). Imperceptible in practice.
- `TimelineView(.animation)` stops updating once all chars are revealed (no idle overhead).
- Streaming skips cache; non-streaming uses cache as before.
