import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// 노치 패널 한 칸을 차지하는 스크린샷 선반.
/// 최신 스크린샷을 세로로 쌓아 보여주고, 클릭으로 열거나 드래그로 꺼낼 수 있다.
struct NotchScreenshotShelfView: View {
    /// 콘텐츠 박스 배경색. 전경 대비 계산에 쓴다.
    let backgroundHex: String
    /// Glass 재질에서는 semantic foreground를 쓴다.
    let usesSemanticForeground: Bool

    @State private var urls: [URL] = ScreenshotShelf.previewOverride ?? []
    @State private var isRefreshing = false
    @State private var isHeaderHovered = false
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var usesDarkCustomForeground: Bool {
        !usesSemanticForeground
            && NotchContrastPolicy.usesDarkForeground(backgroundHex: backgroundHex)
    }

    private var customPrimary: Color {
        usesDarkCustomForeground ? .black.opacity(0.87) : .white.opacity(0.9)
    }

    private var customSecondary: Color {
        usesDarkCustomForeground
            ? .black.opacity(0.65)
            : .white.opacity(
                NotchContrastPolicy.secondaryTextOpacity(backgroundHex: backgroundHex))
    }

    private var customTertiary: Color {
        usesDarkCustomForeground
            ? .black.opacity(0.5)
            : .white.opacity(
                NotchContrastPolicy.tertiaryTextOpacity(backgroundHex: backgroundHex))
    }

    private var rowHoverBackground: Color {
        usesSemanticForeground
            ? .primary.opacity(0.08)
            : (usesDarkCustomForeground ? .black.opacity(0.08) : .white.opacity(0.16))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 제목을 누르면 시스템 스크린샷 저장 폴더를 Finder로 연다.
            // 경로는 `com.apple.screencapture location` 설정에서 오므로
            // 스크린샷을 한 장도 찍기 전에도 동작한다.
            Button {
                NSWorkspace.shared.open(ScreenshotShelf.directory())
            } label: {
                header
            }
            .buttonStyle(.plain)
            .onHover { isHeaderHovered = $0 }
            .help("Open the screenshot folder in Finder")
            .accessibilityLabel("Screenshots")
            .accessibilityHint("Opens the screenshot folder in Finder")

            if urls.isEmpty {
                Text("No recent screenshots")
                    .font(DS.notchBody)
                    .foregroundColor(
                        usesSemanticForeground ? .secondary : customTertiary
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            } else {
                rows
            }
        }
        .onAppear { refresh() }
        // 패널을 열어둔 채 새 스크린샷을 찍어도 몇 초 안에 나타난다.
        .onReceive(refreshTimer) { _ in
            refresh()
        }
    }

    /// 다른 칸 제목과 같은 색 (Glass: 본문색 62%).
    private var headingColor: Color {
        usesSemanticForeground ? Color.primary.opacity(0.62) : customSecondary
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "camera.viewfinder")
                .font(DS.notchLabel)
                .foregroundColor(headingColor)
            Text("Screenshots")
                .font(DS.notchLabel)
                .foregroundColor(headingColor)
            // 호버 시에만 Finder로 이동한다는 단서를 보여준다.
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(usesSemanticForeground ? .secondary : customSecondary)
                .opacity(isHeaderHovered ? 1 : 0)
        }
        .shadow(
            color: .black.opacity(
                usesSemanticForeground || usesDarkCustomForeground ? 0 : 0.75),
            radius: 1.5, y: 0.5
        )
        .padding(.horizontal, 6)
        .frame(height: DS.notchHeaderHeight)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(isHeaderHovered ? rowHoverBackground : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var rows: some View {
        ForEach(urls, id: \.self) { url in
            ScreenshotShelfRow(
                url: url,
                primaryForeground: usesSemanticForeground ? .primary : customPrimary,
                secondaryForeground: usesSemanticForeground
                    ? .secondary : customTertiary,
                borderForeground: usesSemanticForeground
                    ? .secondary.opacity(0.45)
                    : (usesDarkCustomForeground
                        ? .black.opacity(0.15) : .white.opacity(0.15)),
                textShadowOpacity: usesSemanticForeground || usesDarkCustomForeground
                    ? 0 : 0.75,
                hoverBackground: rowHoverBackground)
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        ScreenshotShelf.recentScreenshotsAsync { screenshots in
            urls = screenshots
            isRefreshing = false
        }
    }
}

private struct ScreenshotShelfRow: View {
    let url: URL
    let primaryForeground: Color
    let secondaryForeground: Color
    let borderForeground: Color
    let textShadowOpacity: Double
    let hoverBackground: Color

    @State private var thumbnail: NSImage?
    @State private var modified: Date?
    @State private var isHovered = false

    init(
        url: URL, primaryForeground: Color, secondaryForeground: Color,
        borderForeground: Color, textShadowOpacity: Double, hoverBackground: Color
    ) {
        self.url = url
        self.primaryForeground = primaryForeground
        self.secondaryForeground = secondaryForeground
        self.borderForeground = borderForeground
        self.textShadowOpacity = textShadowOpacity
        self.hoverBackground = hoverBackground
        // 파일 4개의 stat은 가볍다. 첫 프레임부터 시각이 보여 행이 비어 보이지 않는다.
        _modified = State(
            initialValue: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate)
        _thumbnail = State(initialValue: ThumbnailLoader.cachedImage(for: url, maxPixelSize: 96))
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
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(secondaryForeground)
                    }
                }
                .frame(width: 34, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(borderForeground, lineWidth: 0.5)
                )

                // 썸네일과 시각 사이를 비워 시각을 행의 오른쪽 끝에 붙인다.
                Spacer(minLength: 6)
                // 잘린 파일명 대신 찍은 시각. 파일명은 툴팁과 VoiceOver로 제공한다.
                Text(modified.map { ScreenshotShelfPolicy.relativeLabel(for: $0) } ?? " ")
                    .font(DS.notchBody)
                    .foregroundColor(primaryForeground)
                    .shadow(
                        color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5
                    )
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .padding(.horizontal, 6)
            // 목록 한 줄과 같은 26pt: 썸네일 22 + 위아래 2.
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        // 드래그로 파일을 다른 앱/Finder에 떨어뜨릴 수 있다.
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .help(url.lastPathComponent)
        .accessibilityLabel("Open screenshot \(url.lastPathComponent)")
        .task(id: url) {
            modified =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            thumbnail = await ThumbnailLoader.image(for: url, maxPixelSize: 96)
        }
    }
}
