import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 노치 패널 한 칸을 차지하는 파일 드롭 존.
/// 파일을 떨어뜨리면 앱 보관함(Shelf)에 복사되고, 클릭으로 열거나
/// 드래그로 꺼내거나 hover의 x로 보관함에서 지울 수 있다.
struct NotchDropShelfView: View {
    @State private var files: [URL] = []
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(DS.captionFont)
                    .foregroundColor(DS.accent)
                Text("Shelf")
                    .font(DS.captionFont.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))
            }
            .shadow(color: .black.opacity(0.75), radius: 1.5, y: 0.5)
            .padding(.horizontal, 6)
            .padding(.bottom, 1)

            if files.isEmpty {
                Text("Drop files here")
                    .font(DS.captionFont)
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            } else {
                ForEach(files, id: \.self) { url in
                    DropShelfRow(url: url) {
                        DropShelf.remove(url)
                        files = DropShelf.recentFiles()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(isDropTargeted ? Color.white.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? DS.accent : Color.clear,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .dropDestination(for: URL.self) { urls, _ in
            let stored = DropShelf.store(urls)
            files = DropShelf.recentFiles()
            return !stored.isEmpty
        } isTargeted: {
            isDropTargeted = $0
        }
        .onAppear { files = DropShelf.recentFiles() }
    }
}

private struct DropShelfRow: View {
    let url: URL
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(url.lastPathComponent)
                    .font(DS.captionFont)
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.75), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(url.lastPathComponent) from shelf")
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        // 드래그로 파일을 다른 앱/Finder에 떨어뜨릴 수 있다.
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .accessibilityLabel("Open \(url.lastPathComponent)")
    }
}
