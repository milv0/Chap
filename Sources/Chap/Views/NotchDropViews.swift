import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Finder식 파일 아이템: 위에 아이콘/썸네일, 아래에 파일명.
/// 클릭으로 열고, 드래그로 꺼내고, hover의 x로 보관함에서 지운다.
struct NotchDropFileItem: View {
    let url: URL
    let onRemove: () -> Void

    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            VStack(spacing: 5) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Text(url.lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.75), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 68)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.16) : Color.clear)
            )
            .overlay(alignment: .topTrailing) {
                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(url.lastPathComponent) from Chap Drop")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        // 드래그로 파일을 다른 앱/Finder에 떨어뜨릴 수 있다.
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .accessibilityLabel("Open \(url.lastPathComponent)")
        .task(id: url) { thumbnail = Self.loadThumbnail(for: url) }
    }

    /// 이미지 파일은 원본 전체 디코딩 없이 작은 썸네일을 만든다.
    private static func loadThumbnail(for url: URL) -> NSImage? {
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif"]
        guard imageExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 72,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}

/// 노치 왼쪽에 붙는 정사각형 Drop 배지 도커. 보관함에 파일이 있을 때만
/// 표시되며, 아이콘과 파일 개수 배지를 보여준다.
struct NotchDropBadgeView: View {
    let count: Int

    var body: some View {
        ZStack {
            // 노치 쪽(왼쪽)은 직선으로 하드웨어와 융합하고, 바깥(오른쪽)만
            // 도커 문법을 따른다: 상단 오목 플레어 + 하단 볼록 라운드.
            NotchBadgeShape(
                flareRadius: NotchGeometry.dockFlareRadius,
                bottomCornerRadius: NotchGeometry.badgeCornerRadius
            )
            .fill(Color.black)

            // 콘텐츠는 노치 밖으로 보이는 구간(겹침~오른쪽 벽) 안에 정렬.
            // 카운트 칩이 플레어가 깎아낸 투명 모서리로 나가지 않게 한다.
            // 아이콘과 숫자 배지를 한 덩어리로 묶어 광학 보정도 함께 움직인다.
            Image(systemName: "tray.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .overlay(alignment: .topTrailing) {
                    Text("\(min(count, 99))")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(DS.accent))
                        // 아이콘 우상단 모서리에 걸치도록 살짝 바깥으로.
                        .offset(x: 7, y: -6)
                }
                // 우상단 숫자 배지의 무게 때문에 기하 중앙이 아니라
                // 왼쪽으로 4pt 민 광학 중앙에 둔다.
                .offset(x: -4, y: 1)
                .padding(.leading, NotchLauncherPolicy.dropBadgeNotchOverlap)
                .padding(.trailing, NotchGeometry.dockFlareRadius)
        }
        // 개발용: Drop 배지의 현재 영역을 흰 선으로 표시한다 (Debug 전용).
        #if DEBUG
            .overlay(
                NotchBadgeShape(
                    flareRadius: NotchGeometry.dockFlareRadius,
                    bottomCornerRadius: NotchGeometry.badgeCornerRadius
                )
                .stroke(Color.white, lineWidth: 1)
            )
        #endif
        .accessibilityLabel("Chap Drop: \(count) files")
    }
}

/// Drop 배지 실루엣. 노치 쪽(왼쪽) 변은 직선이라 하드웨어 노치와 그대로
/// 융합하고, 바깥(오른쪽)만 상단 오목 플레어와 하단 볼록 라운드를 갖는다.
/// 대칭인 NotchDockShape을 쓰면 노치 접합부에도 플레어·라운드가 파여
/// 배지가 분리된 블롭처럼 보인다.
struct NotchBadgeShape: Shape {
    let flareRadius: CGFloat
    let bottomCornerRadius: CGFloat
    /// true면 좌우 반전: 노치 왼쪽 배지용 (직선 변이 오른쪽, 플레어가 왼쪽).
    var mirrored = false

    func path(in rect: CGRect) -> Path {
        let base = basePath(in: rect)
        guard mirrored else { return base }
        var flip = CGAffineTransform(translationX: rect.maxX + rect.minX, y: 0)
            .scaledBy(x: -1, y: 1)
        guard let flipped = base.cgPath.copy(using: &flip) else { return base }
        return Path(flipped)
    }

    private func basePath(in rect: CGRect) -> Path {
        let fl = flareRadius
        let br = bottomCornerRadius
        var path = Path()

        // 상단 왼쪽(노치 밑)에서 시작해 왼쪽 변은 직선으로 내려간다.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        // 하단 변 → 바깥쪽 볼록 라운드.
        path.addLine(to: CGPoint(x: rect.maxX - fl - br, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.maxX - fl - br, y: rect.maxY - br), radius: br,
            startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        // 바깥 벽을 올라가 오목 플레어로 상단 라인에 합류.
        path.addLine(to: CGPoint(x: rect.maxX - fl, y: rect.minY + fl))
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + fl), radius: fl,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 노치 왼쪽에 붙는 Keep Awake 배지. 상시 표시는 상단바 아이콘 색이
/// 담당하므로, 이 배지는 세션 시작 시 잠깐 피크했다가 사라지고
/// 메인 도커가 열려 있는 동안에만 남은 시간(h:mm)과 함께 보인다.
/// 순수 표시용이라 마우스를 받지 않는다.
struct NotchAwakeBadgeView: View {
    let sessionEnd: Date?
    /// 메인 도커 위 확장 형태 여부. 피크는 컴팩트(아이콘만)다.
    let expanded: Bool

    var body: some View {
        let bodyWidth =
            expanded
            ? NotchGeometry.badgeExpandedBodyWidth : NotchGeometry.badgeBodyWidth
        let shape = NotchBadgeShape(
            flareRadius: NotchGeometry.dockFlareRadius,
            bottomCornerRadius: NotchGeometry.badgeCornerRadius,
            mirrored: true)

        ZStack {
            shape.fill(Color.black)

            HStack(spacing: 5) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 12))
                    // Keep Awake 활성 시각 언어와 통일된 테마 블루.
                    .foregroundColor(DS.accent)
                if expanded, let sessionEnd {
                    // 분 단위 갱신. 항상 h:mm이라 폭이 흔들리지 않는다.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(
                            KeepAwakePolicy.remainingClockLabel(
                                until: sessionEnd, now: context.date)
                        )
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(.leading, NotchGeometry.dockFlareRadius + 4)
            .padding(.trailing, NotchLauncherPolicy.dropBadgeNotchOverlap + 5)
            .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
            .offset(x: expanded ? -5 : 0, y: 1)
        }
        .clipShape(shape)
        // 개발용: 펼쳐진 배지 영역을 흰 선으로 표시한다 (Debug 빌드 전용).
        #if DEBUG
            .overlay(shape.stroke(Color.white, lineWidth: 1).opacity(expanded ? 1 : 0))
        #endif
        .frame(
            width: NotchLauncherPolicy.dropBadgeNotchOverlap + bodyWidth
                + NotchGeometry.dockFlareRadius
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .accessibilityLabel("Keep Awake active")
    }
}
