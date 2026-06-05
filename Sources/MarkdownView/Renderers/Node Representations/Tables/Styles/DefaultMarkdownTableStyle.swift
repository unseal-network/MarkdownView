//
//  DefaultTableStyle.swift
//  MarkdownView
//
//  Created by LiYanan2004 on 2025/4/17.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Default markdown table style that applies to a MarkdownView.
public struct DefaultMarkdownTableStyle: MarkdownTableStyle {
    /// A boolean value that indicates whether to display separators between rows.
    public var showsRowSeparators: Bool = true

    public func makeBody(configuration: Configuration) -> some View {
        DefaultMarkdownTable(
            configuration: configuration,
            showsRowSeparators: showsRowSeparators
        )
    }
}

extension MarkdownTableStyle where Self == DefaultMarkdownTableStyle {
    /// Default markdown table style.
    static public var `default`: DefaultMarkdownTableStyle { .init() }

    /// Default markdown table style with control over row separator visibility.
    static public func `default`(showsRowSeparators: Bool) -> DefaultMarkdownTableStyle {
        .init(showsRowSeparators: showsRowSeparators)
    }
}

fileprivate struct DefaultMarkdownTable: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool

    @State private var isFullscreen = false

    private var spacing: CGFloat { showsRowSeparators ? 6 : 12 }

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
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        configuration.table.header
                        ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (index, row) in
                            if showsRowSeparators {
                                Divider()
                            }
                            row
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxHeight: 280)
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [.clear, tableBackground.opacity(0.85)],
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
        .font(.footnote)
        .markdownTableCellPadding(spacing)
        .padding(8)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .tableCardBackground()
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
            TableFullscreenSheet(
                configuration: configuration,
                showsRowSeparators: showsRowSeparators
            )
            .tableSheetDetents()
        }
    }
}

fileprivate extension View {
    @ViewBuilder
    func tableSheetDetents() -> some View {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.presentationDetents([.large])
        } else {
            self
        }
    }

    @ViewBuilder
    func tableCardBackground(cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        }
    }
}

// MARK: - Fullscreen Sheet

fileprivate struct TableFullscreenSheet: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool

    @Environment(\.dismiss) private var dismiss

    private var spacing: CGFloat { showsRowSeparators ? 6 : 12 }

    var body: some View {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            VStack(spacing: 0) {
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
                        ForEach(Array(configuration.table.rows.enumerated()), id: \.offset) { (index, row) in
                            if showsRowSeparators {
                                Divider()
                            }
                            row
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .font(.footnote)
                .markdownTableCellPadding(spacing)
                .padding(8)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .onAppear { requestLandscape() }
            .onDisappear { requestPortrait() }
        }
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
