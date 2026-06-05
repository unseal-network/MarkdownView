# Mobile Table Display — Design Spec

**Date:** 2026-06-05  
**Status:** Approved

## Problem

On narrow screens (iPhone portrait), Markdown table cells wrap text aggressively, making each row extremely tall and the table nearly unreadable. The root cause is that the existing `Grid`-based renderer lets cells shrink to the container width and wrap content freely.

## Solution Overview

Two-phase delivery prioritized for long-list performance (tables appear in a chat message list where many may be visible simultaneously).

### P0 — Lightweight horizontal scroll + fullscreen sheet

**Goal:** Eliminate text wrapping in cells; provide a fullscreen path for full data review.

Components:

1. **Horizontal scroll with `fixedSize`**  
   Wrap the `Grid` in `ScrollView(.horizontal, showsIndicators: false)` and apply `.fixedSize(horizontal: true, vertical: false)` to the Grid. Cells stop wrapping; the table becomes naturally wider than the screen and horizontally scrollable. Row heights collapse to a single line per cell.

2. **Right-edge gradient fade**  
   A `LinearGradient` overlay on the right side of the table (background color → clear, ~32 pt wide) hints that more columns exist off-screen. Shown only when the table is inside a `ScrollView` context (always in practice). No GeometryReader, no preference keys — just a static overlay.

3. **Expand button**  
   An `arrow.up.left.and.arrow.down.right` SF Symbol button overlaid at the top-right corner of the table. Always visible (no overflow detection needed — avoids GeometryReader). Tapping it opens the fullscreen sheet.

4. **Fullscreen landscape sheet**  
   - Presented via `.sheet(isPresented: $isFullscreen)` with `.presentationDetents([.large])`
   - Content: same `Grid` with `fixedSize` inside `ScrollView(.horizontal)`, but with a header bar ("表格" title + ✕ close button)
   - On `.onAppear`: call `UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))` — best-effort; silently ignored if the host app does not support landscape
   - On `.onDisappear`: restore `.portrait`
   - Sheet content is allocated only when open — zero cost while the table is in the list

### P1 — Sticky first column (future, fullscreen only)

Implement sticky first column **inside the fullscreen sheet only**, where it's a single table not in a long list. Uses the existing `MarkdownTableCellStyleCollectionPreference` (already tracks per-cell rects) to read row heights, then overlays a non-scrolling `VStack` rendering column 0 cells with exact `frame(height:)` values.

Not in the vertical list view — avoids: 2× cell renders, additional preference propagation, and extra layout passes per visible table.

## Files Changed

| File | Change |
|------|--------|
| `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift` | Wrap Grid in `ScrollView(.horizontal)` + `fixedSize`; add expand button; add gradient overlay |
| `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/TableFullscreenSheet.swift` | New: fullscreen sheet view with header bar + orientation management |

No new public API. `DefaultMarkdownTableStyle` behavior changes automatically for all users.

## Performance Constraints

- Zero `GeometryReader` in the list-item path
- Zero additional `PreferenceKey` propagation in the list-item path  
- Fullscreen sheet view is not allocated until opened
- `fixedSize` on Grid is a layout-time hint; no runtime overhead
- Gradient overlay is a static SwiftUI view; no measurement or preference keys

## Behavior Details

| Scenario | Behavior |
|----------|----------|
| Table fits in screen width | Grid still scrollable; gradient hidden (transparent); expand button visible |
| Table overflows screen width | Grid scrolls horizontally; gradient visible; expand button visible |
| Expand button tapped | Fullscreen sheet opens |
| Host app supports landscape | Sheet auto-rotates to landscape on open |
| Host app portrait-only | Sheet opens in portrait; horizontal scroll available as fallback |
| Sheet closed | Portrait orientation restored; list table unchanged |

## Non-Goals

- Sticky first column in vertical list view (P1)
- Dynamic overflow detection for expand button visibility (simplicity > polish)
- Custom table style changes (this only modifies `DefaultMarkdownTableStyle`)
