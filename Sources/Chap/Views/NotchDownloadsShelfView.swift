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
    /// 칸을 어깨 아이콘으로 접는 요청. nil이면 접기 버튼을 그리지 않는다.
    var onCollapse: (() -> Void)?
    @State private var isColumnHovered = false

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

    private var collapseForeground: Color { headingColor }
    private var collapseHoverBackground: Color { hoverBackground }

    private var hoverBackground: Color {
        if usesSemanticForeground { return .primary.opacity(0.08) }
        return usesDarkCustomForeground ? .black.opacity(0.08) : .white.opacity(0.16)
    }

    private var textShadowOpacity: Double {
        usesSemanticForeground || usesDarkCustomForeground ? 0 : 0.75
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
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
                Spacer(minLength: 4)
                if let onCollapse {
                    NotchCollapseButton(
                        isVisible: isColumnHovered, foreground: collapseForeground,
                        hoverBackground: collapseHoverBackground, action: onCollapse)
                }
            }
            .contextMenu {
                if let onCollapse {
                    Button("Collapse", action: onCollapse)
                }
            }

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
                // 잘린 파일명은 마우스를 올린 줄 바로 위에 전체 이름으로 띄운다. 스크롤 목록 밖(이 칸)에서
                // 그려 목록의 잘림·아래 흐림에 가리지 않고, 칸 폭은 그대로라 레이아웃이 흔들리지 않는다.
                .overlayPreferenceValue(DownloadsFullNameKey.self) { hovered in
                    if let hovered {
                        GeometryReader { geo in
                            let row = geo[hovered.bounds]
                            // macOS 확장 툴팁처럼 잘린 이름 바로 그 자리에 겹쳐 띄운다(이름 글자 시작에 맞춤).
                            // 위아래 줄을 가리지 않고, 길면 칸 오른쪽 밖으로 뻗는다.
                            DownloadsFullNameLabel(name: hovered.name)
                                .frame(height: row.height, alignment: .leading)
                                .offset(
                                    x: row.minX + DownloadsShelfRow.nameLeadingInset
                                        - DownloadsFullNameLabel.horizontalPadding,
                                    y: row.minY)
                        }
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            }
        }
        .onHover { isColumnHovered = $0 }
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
struct DownloadsShelfRow: View {
    /// 줄 왼쪽 끝에서 파일명 글자까지: 좌우 여백 6 + 아이콘 20 + 간격 6.
    static let nameLeadingInset: CGFloat = 32
    let url: URL
    let primary: Color
    let secondary: Color
    let textShadowOpacity: Double
    let hoverBackground: Color

    @State private var thumbnail: NSImage?
    @State private var added: Date?
    @State private var isHovered = false
    @State private var shareAnchor = ShareAnchor()
    /// 줄에 보이는 파일명 폭. 실제 글꼴로 잰 전체 폭보다 좁으면 잘린 것이다.
    @State private var shownNameWidth: CGFloat = .infinity
    /// 지연 후 전체 파일명 말풍선을 띄우는 중인지.
    @State private var showsFullName = DownloadsShelf.previewHoveredURL != nil

    private var isNameTruncated: Bool {
        let ideal = (url.lastPathComponent as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: DS.notchFileNameSize)
        ]).width
        return DownloadsShelfPolicy.needsFullName(
            idealWidth: Double(ideal), shownWidth: Double(shownNameWidth))
    }

    private var publishesFullName: Bool {
        guard isNameTruncated else { return false }
        if let preview = DownloadsShelf.previewHoveredURL { return preview == url }
        return isHovered && showsFullName
    }

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
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { shownNameWidth = geo.size.width }
                                .onChange(of: geo.size.width) { _, width in shownNameWidth = width }
                        })

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
        // 잠깐 머물렀을 때만 말풍선을 띄운다. 떠나면 바로 접는다.
        .task(id: isHovered) {
            guard DownloadsShelf.previewHoveredURL == nil else { return }
            guard isHovered else {
                withAnimation(.easeOut(duration: 0.1)) { showsFullName = false }
                return
            }
            try? await Task.sleep(for: .seconds(DownloadsShelfPolicy.fullNameRevealDelay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15)) { showsFullName = true }
        }
        .anchorPreference(key: DownloadsFullNameKey.self, value: .bounds) { anchor in
            publishesFullName
                ? DownloadsHoveredName(name: url.lastPathComponent, bounds: anchor) : nil
        }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        // 잘린 이름은 말풍선이 대신 보여 주므로 시스템 툴팁은 잘리지 않은 이름에만 남기지 않는다.
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

/// 마우스를 올린 Downloads 줄의 전체 파일명과 줄 위치.
struct DownloadsHoveredName {
    let name: String
    let bounds: Anchor<CGRect>
}

/// 목록 안 줄에서 칸으로 올려 보내는 "지금 전체 이름을 보여 줄 줄". 한 번에 하나만.
struct DownloadsFullNameKey: PreferenceKey {
    static let defaultValue: DownloadsHoveredName? = nil
    static func reduce(value: inout DownloadsHoveredName?, nextValue: () -> DownloadsHoveredName?) {
        value = value ?? nextValue()
    }
}

/// 잘린 파일명 위에 뜨는 말풍선. 패널 스타일과 관계없이 검정 띠와 같은 어두운 바탕에 흰 글자라
/// Mist·Glass 위에서도 같은 대비로 읽힌다.
struct DownloadsFullNameLabel: View {
    let name: String
    static let horizontalPadding: CGFloat = 6

    var body: some View {
        Text(name)
            .font(DS.notchFileName)
            .foregroundColor(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: CGFloat(DownloadsShelfPolicy.fullNameMaxWidth), alignment: .leading)
            .fixedSize()
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(Color.black.opacity(0.86))
            )
            .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
            .accessibilityHidden(true)
    }
}
