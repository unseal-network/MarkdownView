# Mobile Table P0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate text-wrapping in mobile table cells by adding horizontal scroll + fixedSize, a right-edge gradient hint, an always-visible expand button, and a fullscreen landscape sheet.

**Architecture:** Modify `DefaultMarkdownTable` (fileprivate struct inside `DefaultMarkdownTableStyle.swift`) to wrap the Grid in a horizontal ScrollView with `fixedSize`, overlay a gradient and expand button, and present a new `TableFullscreenSheet` view. All new UI is gated behind `#available(iOS 16.0, macOS 13.0, …)` — the iOS 15 fallback path is untouched. No new public API.

**Tech Stack:** SwiftUI, UIKit (orientation request, iOS-only, guarded with `#if os(iOS)`), Swift 6 strict concurrency.

---

## File Map

| File | Action |
|------|--------|
| `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift` | Modify: add `@State`, horizontal scroll, gradient, expand button, sheet presentation |
| `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/TableFullscreenSheet.swift` | Create: fullscreen sheet view with header bar and orientation management |

---

### Task 1: Wrap Grid in horizontal ScrollView + fixedSize

**Files:**
- Modify: `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift`

- [ ] **Step 1: Replace the Grid block with ScrollView + fixedSize**

In `DefaultMarkdownTable.body`, inside the `#available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)` branch, wrap the `Grid` in a `ScrollView(.horizontal, showsIndicators: false)` and add `.fixedSize(horizontal: true, vertical: false)` to the Grid. The rest of the body (`.markdownTableCellPadding`, `.padding(8)`, `.overlay`) stays unchanged.

Replace the entire `fileprivate struct DefaultMarkdownTable` with:

```swift
fileprivate struct DefaultMarkdownTable: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool
    private var spacing: CGFloat {
        showsRowSeparators ? 8 : 16
    }

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        configuration.table.header
                        ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (_, row) in
                            if showsRowSeparators {
                                Divider()
                            }
                            row
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                configuration.table.fallback
                    .showsRowSeparators(showsRowSeparators)
            }
        }
        .markdownTableCellPadding(spacing)
        .padding(8)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 2)
        }
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

```bash
cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add "Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift"
git commit -m "feat: wrap table Grid in horizontal ScrollView with fixedSize"
```

---

### Task 2: Add right-edge gradient fade

**Files:**
- Modify: `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift`

- [ ] **Step 1: Add tableBackground computed property and gradient overlay**

Add a `tableBackground` computed property (platform-conditional) and a `.overlay(alignment: .trailing)` gradient to the `ScrollView`. The gradient is always shown (no measurement needed). Full updated struct:

```swift
fileprivate struct DefaultMarkdownTable: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool
    private var spacing: CGFloat {
        showsRowSeparators ? 8 : 16
    }

    #if canImport(UIKit)
    private var tableBackground: Color { Color(uiColor: .systemBackground) }
    #elseif canImport(AppKit)
    private var tableBackground: Color { Color(nsColor: .windowBackgroundColor) }
    #else
    private var tableBackground: Color { .white }
    #endif

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        configuration.table.header
                        ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (_, row) in
                            if showsRowSeparators {
                                Divider()
                            }
                            row
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [.clear, tableBackground],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)
                    .allowsHitTesting(false)
                }
            } else {
                configuration.table.fallback
                    .showsRowSeparators(showsRowSeparators)
            }
        }
        .markdownTableCellPadding(spacing)
        .padding(8)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 2)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add "Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift"
git commit -m "feat: add right-edge gradient fade hint to scrollable table"
```

---

### Task 3: Add expand button

**Files:**
- Modify: `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift`

- [ ] **Step 1: Add @State and expand button overlay**

Add `@State private var isFullscreen = false` and an `overlay(alignment: .topTrailing)` expand button outside the `#available` block (so `@State` works on all platforms). The button body is gated with `#available`. Full updated struct:

```swift
fileprivate struct DefaultMarkdownTable: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool

    @State private var isFullscreen = false

    private var spacing: CGFloat {
        showsRowSeparators ? 8 : 16
    }

    #if canImport(UIKit)
    private var tableBackground: Color { Color(uiColor: .systemBackground) }
    #elseif canImport(AppKit)
    private var tableBackground: Color { Color(nsColor: .windowBackgroundColor) }
    #else
    private var tableBackground: Color { .white }
    #endif

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        configuration.table.header
                        ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (_, row) in
                            if showsRowSeparators {
                                Divider()
                            }
                            row
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [.clear, tableBackground],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)
                    .allowsHitTesting(false)
                }
            } else {
                configuration.table.fallback
                    .showsRowSeparators(showsRowSeparators)
            }
        }
        .markdownTableCellPadding(spacing)
        .padding(8)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                Button {
                    isFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .padding(5)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add "Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift"
git commit -m "feat: add always-visible expand button to table"
```

---

### Task 4: Create TableFullscreenSheet

**Files:**
- Create: `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/TableFullscreenSheet.swift`

- [ ] **Step 1: Create the file**

```swift
// TableFullscreenSheet.swift

import SwiftUI
#if os(iOS)
import UIKit
#endif

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
struct TableFullscreenSheet: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool

    @Environment(\.dismiss) private var dismiss

    private var spacing: CGFloat {
        showsRowSeparators ? 8 : 16
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("表格")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    configuration.table.header
                    ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (_, row) in
                        if showsRowSeparators {
                            Divider()
                        }
                        row
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .markdownTableCellPadding(spacing)
            .padding(8)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.quaternary, lineWidth: 2)
            }
            .padding()

            Spacer(minLength: 0)
        }
        .onAppear { requestLandscape() }
        .onDisappear { requestPortrait() }
    }

    private func requestLandscape() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }
        #endif
    }

    private func requestPortrait() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        #endif
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add "Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/TableFullscreenSheet.swift"
git commit -m "feat: add TableFullscreenSheet with landscape orientation support"
```

---

### Task 5: Wire up sheet presentation

**Files:**
- Modify: `Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift`

- [ ] **Step 1: Add .sheet modifier to DefaultMarkdownTable**

Add `.sheet(isPresented: $isFullscreen)` after the `.overlay(alignment: .topTrailing)` block. Full final `DefaultMarkdownTable`:

```swift
fileprivate struct DefaultMarkdownTable: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool

    @State private var isFullscreen = false

    private var spacing: CGFloat {
        showsRowSeparators ? 8 : 16
    }

    #if canImport(UIKit)
    private var tableBackground: Color { Color(uiColor: .systemBackground) }
    #elseif canImport(AppKit)
    private var tableBackground: Color { Color(nsColor: .windowBackgroundColor) }
    #else
    private var tableBackground: Color { .white }
    #endif

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        configuration.table.header
                        ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (_, row) in
                            if showsRowSeparators {
                                Divider()
                            }
                            row
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [.clear, tableBackground],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)
                    .allowsHitTesting(false)
                }
            } else {
                configuration.table.fallback
                    .showsRowSeparators(showsRowSeparators)
            }
        }
        .markdownTableCellPadding(spacing)
        .padding(8)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                Button {
                    isFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .padding(5)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
        .sheet(isPresented: $isFullscreen) {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                TableFullscreenSheet(
                    configuration: configuration,
                    showsRowSeparators: showsRowSeparators
                )
                .presentationDetents([.large])
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/jelf/Projects/work/MarkdownView && swift build 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add "Sources/MarkdownView/Renderers/Node Representations/Tables/Styles/DefaultMarkdownTableStyle.swift"
git commit -m "feat: wire up fullscreen sheet presentation from expand button"
```

---

### Task 6: Manual verification in DemoApp

- [ ] **Step 1: Open DemoApp in Xcode and run on iPhone simulator**

Open `DemoApp/DemoApp.xcodeproj`, select an iPhone 15 simulator, and run.

Navigate to the Table section. Verify:
- [ ] Table cells no longer wrap text — each row is a single line
- [ ] Table scrolls horizontally when content exceeds screen width
- [ ] Right-edge gradient fade is visible
- [ ] Expand button (⤢) appears in the top-right corner
- [ ] Tapping expand button opens a fullscreen sheet
- [ ] Sheet shows "表格" title and ✕ button
- [ ] Tapping ✕ dismisses the sheet
- [ ] If the simulator supports landscape, the sheet auto-rotates to landscape on open and back to portrait on close
- [ ] On iOS 15 simulator: table falls back to original behavior (no expand button, no horizontal scroll)

- [ ] **Step 2: Confirm TableDestination covers the test case**

`DemoApp/DemoApp/Destinations/TableDestination.swift` already contains a 4-column table with long content in the "Popular Frameworks/Libraries" and "Creator" columns — this is the target scenario. No extra test data needed.
