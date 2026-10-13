import SwiftUI

/// 모든 노치 도커가 공유하는 채움 스타일.
enum NotchDockStyle {
    /// 위는 진하게, 아래로 갈수록 사용자 불투명도로 흘러내리는 공통 페이드.
    static func fade(_ color: Color, bottomOpacity: Double) -> LinearGradient {
        // 중간 지점은 하단 값과 완전 불투명 사이를 보간해 자연스럽게 흘러내린다.
        let midOpacity = bottomOpacity + (1 - bottomOpacity) * 0.8
        return LinearGradient(
            stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(midOpacity), location: 0.35),
                .init(color: color.opacity(bottomOpacity), location: 1),
            ],
            startPoint: .top, endPoint: .bottom)
    }

    /// Liquid Glass 재질 레이어. macOS 26(Tahoe)+ 에서만 실제 유리가 되고,
    /// 그 이하에서는 빈 뷰라 아래의 색 페이드가 그대로 보인다 (black과 동일).
    ///
    /// 참고: https://developer.apple.com/design/human-interface-guidelines/materials
    @ViewBuilder
    static func liquidGlassLayer<S: Shape>(
        shape: S, material: NotchGlassMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            Group {
                switch material {
                case .clear:
                    // Clear는 뒤 화면이 그대로 비쳐 글자 대비가 떨어진다. 창 배경색(라이트는 흰색,
                    // 다크는 검정 계열)을 얇게 깔아 투명감은 두고 가독성만 끌어올린다.
                    Color.clear.glassEffect(.clear, in: Rectangle())
                        .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.28))
                case .regular:
                    Color.clear.glassEffect(.regular, in: Rectangle())
                }
            }
            // Glass의 광학 edge를 플레어 밖으로 밀어낸 뒤 원래 도커
            // 실루엣으로 잘라, 유리가 검정 꼭짓점까지 끊김 없이 닿게 한다.
            .padding(-NotchGeometry.glassEdgeBleed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shape)
        }
    }

    /// "#RRGGBB" → Color. 형식이 어긋나면 검정.
    static func color(fromHex hex: String) -> Color {
        guard let valid = Config.validNotchPanelColorHex(hex) else { return .black }
        let value = UInt32(valid.dropFirst(), radix: 16) ?? 0
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// Color → "#RRGGBB". 설정 저장용.
    static func hex(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return String(
            format: "#%02X%02X%02X",
            Int(round(ns.redComponent * 255)),
            Int(round(ns.greenComponent * 255)),
            Int(round(ns.blueComponent * 255)))
    }
}

/// Liquid Glass 전용 상단 코너 bridge. NotchDockShape의 오목 플레어가
/// 비워두는 좌우 코너를 채워, Glass 재질이 화면 상단의 검정 꼭짓점까지
/// 이어지게 한다. 검정 PressedStrip은 이 위에 그려져 기존 실루엣을 유지한다.
struct GlassCornerBridgeShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height)
        var path = Path()

        // 왼쪽: 상단 가로선 → 본체 벽 → 오목 arc를 거슬러 꼭짓점으로.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + r), radius: r,
            startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
        path.closeSubpath()

        // 오른쪽 미러.
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 노치 도크 실루엣. macOS 노치처럼 상단 모서리가 화면 상단 라인에서
/// 바깥으로 흐르는 오목 곡선으로 시작해 본체로 이어지고, 하단은 볼록하게 둥글다.
/// 본체 폭은 rect보다 상단 반경만큼 좁고, 오목 플레어가 rect 전체 폭까지 닿는다.
struct NotchDockShape: Shape {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    /// true면 상단 변을 닫지 않는다. 림 스트로크가 노치와 만나는 상단
    /// 라인에 흰 줄을 긋지 않도록 fill용(닫힘)과 분리한다.
    var isRim = false

    func path(in rect: CGRect) -> Path {
        let topR = topCornerRadius
        let bottomR = bottomCornerRadius
        var path = Path()

        // 상단 왼쪽 끝(화면 상단 라인)에서 시작.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // 왼쪽 오목 플레어: 상단 라인이 본체 왼쪽 벽으로 흘러내린다.
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + topR), radius: topR,
            startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        // 본체 왼쪽 벽.
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - bottomR))
        // 하단 왼쪽 볼록 모서리.
        path.addArc(
            center: CGPoint(x: rect.minX + topR + bottomR, y: rect.maxY - bottomR),
            radius: bottomR,
            startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        // 하단 변.
        path.addLine(to: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY))
        // 하단 오른쪽 볼록 모서리.
        path.addArc(
            center: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY - bottomR),
            radius: bottomR,
            startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        // 본체 오른쪽 벽.
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))
        // 오른쪽 오목 플레어: 본체 오른쪽 벽이 상단 라인으로 흘러나간다.
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + topR), radius: topR,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        // 림 모드에서는 상단 변을 긋지 않아 노치와의 경계가 검정으로 남는다.
        if !isRim { path.closeSubpath() }
        return path
    }
}

/// 노치가 배경을 눌러 만든 듯한 검정 띠. 노치·배지 plateau 구간은
/// `centerDepth`로 평평하게 깊고, 바깥으로는 코사인 감쇠로
/// `stripEdgeDepth`까지 부드럽게 얇아진다. 좁은 도커에서는 감쇠 구간이
/// 폭을 넘어 사실상 직선이 되고, 넓은 메인 도커에서 곡선이 드러난다.
struct PressedStripShape: Shape {
    let plateauHalfWidth: CGFloat
    let centerDepth: CGFloat
    /// 도커 외곽에서 남길 검정 깊이. Custom 기본은 6pt, Glass는 0으로
    /// 설정해 상단 둥근 코너가 Glass 재질로 보이게 한다.
    var edgeDepth: CGFloat = NotchGeometry.stripEdgeDepth

    func path(in rect: CGRect) -> Path {
        let edge = edgeDepth
        let falloff = NotchGeometry.stripFalloff
        let cx = rect.midX

        func depth(at x: CGFloat) -> CGFloat {
            let distance = abs(x - cx)
            if distance <= plateauHalfWidth { return centerDepth }
            let t = min((distance - plateauHalfWidth) / falloff, 1)
            // 코사인 반파: 1→0으로 부드럽게 감쇠.
            let factor = 0.5 + 0.5 * cos(t * .pi)
            return edge + (centerDepth - edge) * factor
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + depth(at: rect.maxX)))
        // 오른쪽→왼쪽으로 곡선 경계를 샘플링한다.
        let samples = 96
        for step in 0...samples {
            let x = rect.maxX - rect.width * CGFloat(step) / CGFloat(samples)
            path.addLine(to: CGPoint(x: x, y: rect.minY + depth(at: x)))
        }
        path.closeSubpath()
        return path
    }
}

/// 노치 칸 폭 계산용 글자 측정. 실제 글꼴(13pt 본문, 11pt semibold 제목)로 잰다.
enum NotchTextMetrics {
    /// 목록 줄 이름(12pt). `DS.notchRowNameSize`와 같다.
    private static let body = NSFont.systemFont(ofSize: 12)
    private static let label = NSFont.systemFont(ofSize: 11, weight: .semibold)
    private static let meta = NSFont.systemFont(ofSize: 10, weight: .medium)

    static func bodyWidth(_ text: String) -> CGFloat {
        // SwiftUI 렌더링은 AppKit 측정보다 1~2pt 넓게 그리므로 여유를 둔다.
        ceil((text as NSString).size(withAttributes: [.font: body]).width) + 3
    }

    /// 보조 정보(10pt medium) 폭. 스크린샷·다운로드 칸의 시각 문구에 쓴다.
    static func metaWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: meta]).width) + 2
    }

    static func labelWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: label]).width) + 2
    }

    /// 목록 한 줄: 좌우 여백 6 + 이름 + (간격 6 + Spacer 8 + 간격 6 + 키캡).
    /// 키캡은 ⌥를 눌러도 폭이 변하지 않도록 "⌥키" 폭을 잡고 좌우 4pt 여백을 둔다.
    static func rowWidth(name: String, keycap: String?) -> CGFloat {
        let keycapWidth = keycap.map { 20 + metaWidth("⌥\($0)") + 2 + 8 } ?? 0
        return 12 + bodyWidth(name) + keycapWidth
    }

    /// 제목 줄: 좌우 여백 6 + 아이콘 약 13 + 간격 5 + 제목.
    static func headerWidth(title: String) -> CGFloat {
        12 + 13 + 5 + labelWidth(title)
    }
}
