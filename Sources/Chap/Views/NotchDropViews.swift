import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 노치 패널 한 칸을 차지하는 Chap Drop 목록.
/// 파일을 떨어뜨리면 보관함에 복사되고, 클릭으로 열거나
/// 드래그로 꺼내거나 hover의 x로 보관함에서 지울 수 있다.
struct NotchDropListView: View {
    @State private var files: [URL] = []
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(DS.captionFont)
                    .foregroundColor(DS.accent)
                Text("Drop")
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
                    DropRow(url: url) {
                        ChapDrop.remove(url)
                        files = ChapDrop.recentFiles()
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
            let stored = ChapDrop.store(urls)
            files = ChapDrop.recentFiles()
            return !stored.isEmpty
        } isTargeted: {
            isDropTargeted = $0
        }
        .onAppear { files = ChapDrop.recentFiles() }
    }
}

/// 파일을 끌고 노치에 댔을 때 뜨는 드롭 존. Drop 리스트 도커와 같은
/// 폭·패딩·실루엣을 써서 두 도커가 같은 크기로 보인다.
struct NotchDropZoneView: View {
    /// 상단바(노치) 구간 높이. 이만큼 검정이 위로 연장되어 노치를 감싼다.
    let topInset: CGFloat
    /// 도커 콘텐츠 폭. 배지 왼쪽 끝~노치 오른쪽 끝 구간에서 계산된다.
    let contentWidth: CGFloat
    /// 본체 하단 불투명도. 메인 도커와 같은 설정값을 공유한다.
    let bottomOpacity: Double
    /// 콘텐츠 박스 배경색 ("#RRGGBB").
    let colorHex: String
    /// 눌린 검정 띠의 plateau 반폭.
    let stripPlateauHalfWidth: CGFloat
    /// 드롭 완료 콜백. 컨트롤러가 존을 닫는 데 쓴다.
    let onDropped: () -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 20))
                .foregroundColor(isDropTargeted ? DS.accent : .white.opacity(0.7))
            Text("Chap Drop")
                .font(DS.bodyFont.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: contentWidth, height: NotchDropDock.zoneContentHeight)
        .padding(.horizontal, DS.paddingSmall)
        .padding(.top, topInset + NotchGeometry.stripPressDepth + 8)
        .padding(.bottom, DS.paddingSmall)
        .background(
            NotchDockStyle.dockBackground(
                shape: NotchDropDock.shape, topInset: topInset,
                stripPlateauHalfWidth: stripPlateauHalfWidth,
                colorHex: colorHex, bottomOpacity: bottomOpacity
            )
            .overlay(
                NotchDropDock.rimShape
                    .stroke(
                        isDropTargeted
                            ? DS.accent.opacity(0.8) : Color.white.opacity(0.08),
                        lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
        )
        .padding(.horizontal, NotchLauncherPanelView.shadowPadding)
        .padding(.bottom, NotchLauncherPanelView.shadowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dropDestination(for: URL.self) { urls, _ in
            let stored = ChapDrop.store(urls)
            onDropped()
            return !stored.isEmpty
        } isTargeted: {
            isDropTargeted = $0
        }
    }
}

/// Drop 도커(드롭 존·파일 리스트)가 공유하는 지오메트리와 실루엣.
enum NotchDropDock {
    /// 드롭 존 콘텐츠 높이. 드롭만 받는 표면이라 낮게 유지한다.
    static let zoneContentHeight: CGFloat = NotchGeometry.dropZoneContentHeight
    /// 상단 오목 플레어 반경. 폭 보정 계산이 실루엣과 어긋나지 않게 공유한다.
    static let topCornerRadius: CGFloat = NotchGeometry.dockFlareRadius

    static var shape: NotchDockShape {
        NotchDockShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: NotchGeometry.dockBottomRadius)
    }

    static var rimShape: NotchDockShape {
        NotchDockShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: NotchGeometry.dockBottomRadius, isRim: true)
    }
}

/// Drop 배지에 마우스를 올렸을 때 펼쳐지는 파일 도커.
/// 파일을 Finder처럼 아이콘 그리드로 보여준다. 폭은 배지 span이 최소,
/// 메인 런처 도커 폭이 최대이며 파일 수에 따라 자연스럽게 늘어난다.
struct NotchDropPanelView: View {
    /// 상단바(노치) 구간 높이. 이만큼 검정이 위로 연장되어 노치·배지를 감싼다.
    let topInset: CGFloat
    /// 최소 콘텐츠 폭 (배지 span 기준).
    let minContentWidth: CGFloat
    /// 최대 콘텐츠 폭 (메인 도커 폭 기준).
    let maxContentWidth: CGFloat
    /// 본체 하단 불투명도. 메인 도커와 같은 설정값을 공유한다.
    let bottomOpacity: Double
    /// 콘텐츠 박스 배경색 ("#RRGGBB").
    let colorHex: String
    /// 눌린 검정 띠의 plateau 반폭.
    let stripPlateauHalfWidth: CGFloat
    /// 콘텐츠 크기 변화 통지. 열려 있는 동안 파일이 추가·삭제되면
    /// 컨트롤러가 창을 같은 앵커로 리사이즈한다.
    var onSizeChange: ((CGSize) -> Void)?

    @State private var files: [URL] = []
    @State private var isDropTargeted = false
    /// 그리드의 자연(ideal) 크기. 창 크기에 눌리지 않도록 숨김 복사본으로 잰다.
    @State private var gridIdeal: CGSize = .zero

    /// 자연 폭을 min~max로 클램프한 실제 콘텐츠 폭.
    private var contentWidth: CGFloat {
        min(max(gridIdeal.width, minContentWidth), max(minContentWidth, maxContentWidth))
    }

    private var contentHeight: CGFloat {
        max(gridIdeal.height, 74)
    }

    /// 창이 가져야 할 발자국 (도커 + 그림자 여백). 산술 계산이라
    /// 창 크기 제약과 무관하게 항상 정확하다.
    private var footprint: CGSize {
        CGSize(
            width: contentWidth + DS.paddingSmall * 2
                + NotchLauncherPanelView.shadowPadding * 2,
            height: contentHeight + topInset + 8 + DS.paddingSmall
                + NotchLauncherPanelView.shadowPadding)
    }

    var body: some View {
        gridContent
            .frame(width: contentWidth, height: contentHeight, alignment: .leading)
            // 숨김 복사본이 창 크기와 무관한 자연 크기를 계측한다.
            .background(
                gridContent
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { gridIdeal = geo.size }
                                .onChange(of: geo.size) { _, size in gridIdeal = size }
                        }
                    )
            )
            .onChange(of: gridIdeal) { _, _ in onSizeChange?(footprint) }
            .padding(.horizontal, DS.paddingSmall)
            .padding(.top, topInset + NotchGeometry.stripPressDepth + 8)
            .padding(.bottom, DS.paddingSmall)
            .background(
                NotchDockStyle.dockBackground(
                    shape: NotchDropDock.shape, topInset: topInset,
                    stripPlateauHalfWidth: stripPlateauHalfWidth,
                    colorHex: colorHex, bottomOpacity: bottomOpacity
                )
                .overlay(
                    NotchDropDock.rimShape
                        .stroke(
                            isDropTargeted
                                ? DS.accent.opacity(0.8) : Color.white.opacity(0.08),
                            lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
            )
            .padding(.horizontal, NotchLauncherPanelView.shadowPadding)
            .padding(.bottom, NotchLauncherPanelView.shadowPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .dropDestination(for: URL.self) { urls, _ in
                let stored = ChapDrop.store(urls)
                files = ChapDrop.recentFiles(limit: DropPolicy.maxDockItems)
                return !stored.isEmpty
            } isTargeted: {
                isDropTargeted = $0
            }
            .onAppear { files = ChapDrop.recentFiles(limit: DropPolicy.maxDockItems) }
    }

    /// 그리드 본문. 실제 표시와 숨김 계측 복사본이 공유한다.
    @ViewBuilder private var gridContent: some View {
        if files.isEmpty {
            Text("Drop files here")
                .font(DS.captionFont)
                .foregroundColor(.white.opacity(0.45))
        } else {
            // Finder처럼 아이콘 + 이름의 가로 그리드.
            HStack(alignment: .top, spacing: DS.spacingSmall) {
                ForEach(files, id: \.self) { url in
                    DropGridItem(url: url) {
                        ChapDrop.remove(url)
                        files = ChapDrop.recentFiles(limit: DropPolicy.maxDockItems)
                    }
                }
            }
        }
    }
}

/// Finder식 그리드 한 칸: 위에 아이콘/썸네일, 아래에 파일명.
/// 클릭으로 열고, 드래그로 꺼내고, hover의 x로 보관함에서 지운다.
private struct DropGridItem: View {
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
        .accessibilityLabel("Chap Drop: \(count) files")
    }
}

private struct DropRow: View {
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
                    .accessibilityLabel("Remove \(url.lastPathComponent) from Chap Drop")
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

/// Drop 배지 실루엣. 노치 쪽(왼쪽) 변은 직선이라 하드웨어 노치와 그대로
/// 융합하고, 바깥(오른쪽)만 상단 오목 플레어와 하단 볼록 라운드를 갖는다.
/// 대칭인 NotchDockShape을 쓰면 노치 접합부에도 플레어·라운드가 파여
/// 배지가 분리된 블롭처럼 보인다.
struct NotchBadgeShape: Shape {
    let flareRadius: CGFloat
    let bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
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
