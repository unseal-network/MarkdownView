//
//  DefaultTableStyle.swift
//  MarkdownView
//
//  Created by LiYanan2004 on 2025/4/17.
//

import SwiftUI

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
