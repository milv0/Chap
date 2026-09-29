import AppKit
import Combine
import SwiftUI

/// 노치 한 칸의 다운로드 선반. ~/Downloads의 최근 파일 4개를 파일 아이콘·이름·받은 시각으로
/// 보여준다. 클릭으로 열고, 드래그로 꺼내고, 우클릭으로 공유하거나 Finder에서 본다.
/// 제목을 누르면 다운로드 폴더를 Finder로 연다.
struct NotchDownloadsShelfView: View {
    /// 콘텐츠 박스 배경색. 전경 대비 계산에 쓴다.
    let backgroundHex: String
    /// Glass 재질에서는 semantic foreground를 쓴다.
    let usesSemanticForeground: Bool

    @State private var urls: [URL] = DownloadsShelf.previewOverride ?? []
    @State private var didLoad = DownloadsShelf.previewOverride != nil
    @State private var isRefreshing = false
    @State private var isHeaderHovered = false
    @Environment(\.colorScheme) private var colorScheme
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var usesDarkCustomForeground: Bool {
        !usesSemanticForeground
            && NotchContrastPolicy.usesDarkForeground(backgroundHex: backgroundHex)
    }

    private var primary: Color {
        if usesSemanticForeground { return .primary }
        return usesDarkCustomForeground ? .black.opacity(0.87) : .white.opacity(0.9)
    }

    private var tertiary: Color {
        if usesSemanticForeground { return .secondary }
        return usesDarkCustomForeground
            ? .black.opacity(0.5)
            : .white.opacity(
                NotchContrastPolicy.tertiaryTextOpacity(backgroundHex: backgroundHex))
    }

    /// 다른 칸 제목과 같은 색 (Glass: 본문색 62%).
    private var headingColor: Color {
        if usesSemanticForeground { return Color.primary.opacity(0.62) }
        return usesDarkCustomForeground
            ? .black.opacity(0.65)
            : .white.opacity(
                NotchContrastPolicy.secondaryTextOpacity(backgroundHex: backgroundHex))
    }

    private var hoverBackground: Color {
        if usesSemanticForeground { return .primary.opacity(0.08) }
        return usesDarkCustomForeground ? .black.opacity(0.08) : .white.opacity(0.16)
    }

    private var textShadowOpacity: Double {
        usesSemanticForeground || usesDarkCustomForeground ? 0 : 0.75
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                NotchShelfFolder.open(DownloadsShelf.directory(), name: "Downloads")
            } label: {
                header
            }
            .buttonStyle(.plain)
            .onHover { isHeaderHovered = $0 }
            .help("Open Downloads in Finder")
            .accessibilityLabel("Downloads")
            .accessibilityHint("Opens the Downloads folder in Finder")

            if urls.isEmpty {
                Text(didLoad ? "No recent downloads" : " ")
                    .font(DS.notchBody)
                    .foregroundColor(tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            } else {
                NotchShelfScrollList(
                    itemCount: urls.count, visibleRows: DownloadsShelfPolicy.visibleRows
                ) {
                    ForEach(urls, id: \.self) { url in
                        DownloadsShelfRow(
                            url: url, primary: primary, secondary: tertiary,
                            textShadowOpacity: textShadowOpacity, hoverBackground: hoverBackground)
                    }
                }
            }
        }
        .onAppear { refresh() }
        // 노치를 열어 둔 채 받은 파일도 몇 초 안에 나타난다.
        .onReceive(refreshTimer) { _ in refresh() }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.circle")
                .font(DS.notchLabel)
                .foregroundColor(
                    DS.notchIconColor(
                        onDarkBackground: usesSemanticForeground
                            ? colorScheme == .dark : !usesDarkCustomForeground))
            Text("Downloads")
                .font(DS.notchLabel)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .opacity(isHeaderHovered ? 1 : 0)
        }
        .foregroundColor(headingColor)
        .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
        .padding(.horizontal, 6)
        .frame(height: DS.notchHeaderHeight)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(isHeaderHovered ? hoverBackground : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func refresh() {
        guard DownloadsShelf.previewOverride == nil, !isRefreshing else { return }
        isRefreshing = true
        DownloadsShelf.recentFilesAsync { files in
            urls = files
            didLoad = true
            isRefreshing = false
        }
    }
}

/// 다운로드 한 줄: 파일 아이콘(이미지는 썸네일), 가운데를 줄인 파일명, 오른쪽 끝의 받은 시각.
private struct DownloadsShelfRow: View {
    let url: URL
    let primary: Color
    let secondary: Color
    let textShadowOpacity: Double
    let hoverBackground: Color

    @State private var thumbnail: NSImage?
    @State private var added: Date?
    @State private var isHovered = false
    @State private var shareAnchor = ShareAnchor()

    init(
        url: URL, primary: Color, secondary: Color, textShadowOpacity: Double,
        hoverBackground: Color
    ) {
        self.url = url
        self.primary = primary
        self.secondary = secondary
        self.textShadowOpacity = textShadowOpacity
        self.hoverBackground = hoverBackground
        // 파일 4개의 stat은 가볍다. 첫 프레임부터 시각이 보여 행이 비어 보이지 않는다.
        _added = State(initialValue: DownloadsShelf.addedDate(of: url))
        _thumbnail = State(initialValue: ThumbnailLoader.cachedImage(for: url, maxPixelSize: 64))
    }

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 6) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                    }
                }
                .frame(width: 20, height: 20)

                Text(url.lastPathComponent)
                    .font(DS.notchFileName)
                    .foregroundColor(primary)
                    .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                Text(added.map { DownloadsShelfRow.shortAge(of: $0) } ?? "")
                    .font(DS.notchMeta)
                    .foregroundColor(secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 6)
            // 목록 한 줄과 같은 26pt: 아이콘 20 + 위아래 3.
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .background(ShareAnchorView(anchor: shareAnchor))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .help(url.lastPathComponent)
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Share…") { NotchSharing.present(url, from: shareAnchor) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open download \(url.lastPathComponent)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { NSWorkspace.shared.open(url) }
        .accessibilityAction(named: "Share") { NotchSharing.present(url, from: shareAnchor) }
        .accessibilityAction(named: "Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        .task(id: url) {
            added = DownloadsShelf.addedDate(of: url)
            thumbnail = await ThumbnailLoader.image(for: url, maxPixelSize: 64)
        }
    }

    /// 한 칸 오른쪽에 맞는 아주 짧은 시각 ("now", "5m", "3h", "1d", "Sep 24").
    static func shortAge(of date: Date, now: Date = Date()) -> String {
        DownloadsShelfPolicy.shortAge(of: date, now: now)
    }
}
