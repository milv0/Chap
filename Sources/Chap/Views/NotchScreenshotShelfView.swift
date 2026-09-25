import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 노치 패널 한 칸을 차지하는 스크린샷 선반.
/// 최신 스크린샷을 세로로 쌓아 보여주고, 클릭으로 열거나 드래그로 꺼낼 수 있다.
struct NotchScreenshotShelfView: View {
    let urls: [URL]
    /// 콘텐츠 박스 배경색. 전경 대비 계산에 쓴다.
    let backgroundHex: String
    /// Glass 재질에서는 semantic foreground를 쓴다.
    let usesSemanticForeground: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "camera.viewfinder")
                    .font(DS.captionFont)
                    .foregroundColor(
                        usesSemanticForeground
                            ? DS.accent
                            : (NotchContrastPolicy.usesAccentForeground(
                                backgroundHex: backgroundHex)
                                ? DS.accent : .white.opacity(0.95)))
                Text("Screenshots")
                    .font(DS.captionFont.weight(.semibold))
                    .foregroundColor(
                        usesSemanticForeground
                            ? .secondary
                            : .white.opacity(
                                NotchContrastPolicy.secondaryTextOpacity(
                                    backgroundHex: backgroundHex)))
            }
            .shadow(
                color: .black.opacity(usesSemanticForeground ? 0 : 0.75),
                radius: 1.5, y: 0.5
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 1)

            if urls.isEmpty {
                Text("No recent screenshots")
                    .font(DS.captionFont)
                    .foregroundColor(
                        usesSemanticForeground
                            ? .secondary
                            : .white.opacity(
                                NotchContrastPolicy.tertiaryTextOpacity(
                                    backgroundHex: backgroundHex))
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            } else {
                ForEach(urls, id: \.self) { url in
                    ScreenshotShelfRow(
                        url: url,
                        primaryForeground: usesSemanticForeground
                            ? .primary : .white.opacity(0.9),
                        secondaryForeground: usesSemanticForeground
                            ? .secondary : .white.opacity(0.4),
                        borderForeground: usesSemanticForeground
                            ? .secondary.opacity(0.45) : .white.opacity(0.15),
                        textShadowOpacity: usesSemanticForeground ? 0 : 0.75)
                }
            }
        }
    }
}

private struct ScreenshotShelfRow: View {
    let url: URL
    let primaryForeground: Color
    let secondaryForeground: Color
    let borderForeground: Color
    let textShadowOpacity: Double

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

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
                .frame(width: 26, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(borderForeground, lineWidth: 0.5)
                )

                Text(url.lastPathComponent)
                    .font(DS.captionFont)
                    .foregroundColor(primaryForeground)
                    .shadow(
                        color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
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
        .accessibilityLabel("Open screenshot \(url.lastPathComponent)")
        .task(id: url) {
            thumbnail = Self.loadThumbnail(for: url)
        }
    }

    /// 원본 전체 디코딩 없이 작은 썸네일만 만든다.
    private static func loadThumbnail(for url: URL) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
