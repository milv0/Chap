import SwiftUI

// MARK: - Focus 다이얼 (Focus·Timer 모드 공용)

/// 다이얼 안쪽 원(누르는 자리). 호 안쪽을 거의 채우는 원이 통째로 스위치이고, 마우스를 올리면 옅게 물든다.
struct FocusDialInner<Content: View>: View {
    let isHovered: Bool
    let hoverTint: Color
    @ViewBuilder let content: () -> Content

    /// 호(반지름 44, 두께 6) 안쪽에 6pt 여유를 둔 원.
    static var diameter: CGFloat { 2 * (44 - 3 - 6) }

    var body: some View {
        content()
            // 숫자 + 짧은 말 두 줄은 원 중심에 그대로 둔다(올리면 숫자가 위로 쏠려 보인다).
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Circle().fill(isHovered ? hoverTint : Color.clear))
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// 다이얼 가운데 두 줄: 큰 숫자와 그 아래 작은 말(On·Off·Start·Stop). 숫자가 주인공이다.
struct FocusDialCenterLabel: View {
    let value: String
    let caption: String
    let valueSize: CGFloat
    let valueColor: Color
    let captionColor: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(captionColor)
        }
    }
}

/// Focus 다이얼. 반원보다 긴 240° 호가 위를 감싸고 아래는 평평하게 열려 있다(속도계처럼).
/// - 꺼짐: 연한 트랙 위에 고른 길이까지 블루 호 + 끝에 손잡이. 호(테두리 띠)를 끌면 12칸 눈금으로 맞춘다.
/// - 켜짐: 같은 눈금에서 남은 시간까지 블루 호가 1초마다 줄어든다(끌 수 없음).
/// 눈금은 1/4·2/4·3/4에 짧은 점(Focus 3·6·9시간, Timer 15·30·45분), 양 끝 아래에 "0"과 최댓값.
struct FocusDial<Center: View>: View {
    let fraction: Double
    let isRunning: Bool
    let palette: NotchWidgetPalette
    /// 오른쪽 끝 눈금 글자 ("12h", "60m").
    let maxLabel: String
    /// 끈 자리의 호 위 비율(0…1). nil이면 끌어서 바꿀 수 없다(켜짐).
    let onPick: ((Double) -> Void)?
    @ViewBuilder let center: () -> Center

    static var size: CGSize { CGSize(width: 104, height: 92) }
    static var lineWidth: CGFloat { 6 }
    /// 원 반지름. 호 아래 빈 곳(120°)이 칸 바닥에 닿지 않도록 중심을 조금 위에 둔다.
    static var radius: CGFloat { 44 }
    static var centerPoint: CGPoint { CGPoint(x: size.width / 2, y: radius + lineWidth / 2 + 1) }

    private var sweep: Double { KeepAwakePolicy.focusDialSweep }
    /// SwiftUI 각도(3시 = 0°, 시계 방향 +). 호는 12시에서 -120°(왼쪽 아래)부터 +120°(오른쪽 아래)까지.
    private var startAngle: Angle { .degrees(-90 - sweep / 2) }

    private func arc(to fraction: Double) -> Path {
        var path = Path()
        path.addArc(
            center: Self.centerPoint, radius: Self.radius, startAngle: startAngle,
            endAngle: startAngle + .degrees(sweep * fraction), clockwise: false)
        return path
    }

    private func point(at fraction: Double, radius: CGFloat) -> CGPoint {
        let angle = (startAngle + .degrees(sweep * fraction)).radians
        return CGPoint(
            x: Self.centerPoint.x + radius * CGFloat(cos(angle)),
            y: Self.centerPoint.y + radius * CGFloat(sin(angle)))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            arc(to: 1)
                .stroke(
                    palette.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            if fraction > 0 {
                arc(to: fraction)
                    .stroke(
                        DS.accent, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                    )
                    .animation(
                        isRunning ? .linear(duration: 1) : .smooth(duration: 0.12), value: fraction)
            }
            // 눈금: 1/4·2/4·3/4 (양 끝은 아래 글자가 맡는다).
            ForEach(1..<4, id: \.self) { index in
                Circle()
                    .fill(palette.secondary.opacity(0.6))
                    .frame(width: 2, height: 2)
                    .position(
                        point(at: Double(index) / 4, radius: Self.radius - Self.lineWidth - 3))
            }
            if !isRunning {
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(DS.accent, lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                    .position(point(at: fraction, radius: Self.radius))
                    .animation(.smooth(duration: 0.12), value: fraction)
            }
            Text("0")
                .position(x: point(at: 0, radius: Self.radius).x, y: Self.size.height - 5)
            Text(maxLabel)
                .position(x: point(at: 1, radius: Self.radius).x, y: Self.size.height - 5)
            center()
                .position(x: Self.centerPoint.x, y: Self.centerPoint.y)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(palette.secondary)
        .frame(width: Self.size.width, height: Self.size.height)
        .contentShape(Rectangle())
        // 호(테두리 띠) 위에서 시작한 끌기만 길이를 바꾼다. 가운데 버튼의 클릭은 그대로 버튼이 받는다.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    guard let onPick else { return }
                    let start = value.startLocation
                    let distance = hypot(start.x - Self.centerPoint.x, start.y - Self.centerPoint.y)
                    guard distance > Self.radius - 16 else { return }
                    onPick(
                        KeepAwakePolicy.focusDialFraction(
                            dx: Double(value.location.x - Self.centerPoint.x),
                            dy: Double(value.location.y - Self.centerPoint.y)))
                },
            including: onPick == nil ? .subviews : .all
        )
        // 제목 줄과 호 꼭대기 사이 숨 쉴 틈. 끌기 좌표는 이 여백 안쪽 다이얼 기준 그대로다.
        .padding(.top, Self.topGap)
    }

    /// 제목과 호 꼭대기 사이 간격. 호 위(제목 줄 아래)와 눈금 글자 아래(도커 바닥까지)의 여백이 눈으로
    /// 같아 보이도록 14pt. 다이얼(92pt) + 간격이 칸 본문 높이(113pt) 안에 들어간다(바닥 7pt 남음).
    static var topGap: CGFloat { 14 }
}

/// 누르는 순간 살짝 눌렸다 튀어 오르는 버튼 모양. "딱" 누르는 손맛을 준다.
struct FocusPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
