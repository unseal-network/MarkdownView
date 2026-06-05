import SwiftUI
#if os(iOS)
import UIKit
#endif

struct TableFullscreenSheet: View {
    var configuration: MarkdownTableStyleConfiguration
    var showsRowSeparators: Bool

    @Environment(\.dismiss) private var dismiss

    private var spacing: CGFloat {
        showsRowSeparators ? 8 : 16
    }

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
