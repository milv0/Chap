import SwiftUI

/// Apple Intelligence(Siri) 테두리처럼 도형 둘레 전체가 여러 색으로 빛나고, 색이 천천히 흐르는 빛.
///
/// 오픈소스 재현들(IntelligenceGlow, AppleIntelligenceGlowEffect, MIT)의 방식을 참고해 Chap 안에 다시 썼다:
/// 색 띠를 두께·흐림을 달리해 여러 겹 겹치고, 색이 테두리를 따라 흐른다.
/// 그 라이브러리들은 각도 그라데이션을 쓰지만, 노치처럼 납작한 도형에서는 아랫변 가운데에 색이 몰려 매듭처럼
/// 끊겨 보인다. 그래서 테두리를 짧은 조각으로 나눠 길이를 따라 색을 고르게 칠한다. 시간만으로 모습이 정해져
/// 타이머가 없고 어느 순간이든 같은 모습으로 다시 그릴 수 있다(렌더 도구).
///
/// - `duration`이 있으면 `startedAt`부터 그동안만 보인다: 짧게 차오르며 두꺼워지고, 머물다가, 옅어지며 사라진다
///   (Keep Awake·Timer를 켤 때 노치 둘레).
/// - `duration`이 nil이면 보이는 동안 계속 빛난다(파일을 노치로 끌 때 도커 테두리). 호출하는 쪽이 조건부로 둔다.
/// 동작 줄이기가 켜져 있으면 색이 흐르지 않는다. 한 번 빛나는 모드는 그리지 않고, 계속 모드는 멈춘 색 테두리만 남긴다.
struct IntelligenceGlow<S: Shape>: View {
    let shape: S
    var palette: NotchGlowPalette = .colorful
    var startedAt = Date()
    var duration: Double? = 1.8
    /// 가장 안쪽 띠 두께(pt). 바깥 띠는 이 값의 배수다.
    var lineWidth: CGFloat = 2.5
    /// 0...1. 전체 밝기.
    var strength: Double = 1
    /// 빛을 도형 안쪽에만 둔다(도커). 하드웨어 노치처럼 안쪽에 픽셀이 없는 도형은 끄고 바깥으로 번지게 한다.
    var clipsToShape = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 겹치는 띠: (두께 배수, 흐림, 불투명도). 안쪽은 또렷하고 바깥은 넓게 번진다.
    private static var layers: [(width: CGFloat, blur: CGFloat, opacity: Double)] {
        [(1, 1, 0.9), (2, 4, 0.8), (3.2, 9, 0.6), (5, 16, 0.45)]
    }

    /// 테두리를 나누는 조각 수. 흐림이 조각 사이 이음새를 덮는다.
    private static var segments: Int { 120 }

    var body: some View {
        Group {
            if reduceMotion {
                if duration == nil { glow(time: 0, level: 1) }
            } else {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    if let duration {
                        if elapsed >= 0, elapsed < duration {
                            glow(time: elapsed, level: Self.envelope(elapsed / duration))
                        }
                    } else {
                        // 계속 모드는 뷰가 다시 만들어져도 처음부터 다시 차오르지 않도록 시작 시각을 쓰지 않는다.
                        // 나타나고 사라지는 것은 호출하는 쪽의 전환(transition)이 맡는다.
                        glow(time: context.date.timeIntervalSinceReferenceDate, level: 1)
                    }
                }
            }
        }
        .modifier(GlowClip(shape: shape, isOn: clipsToShape))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(time: Double, level: Double) -> some View {
        let count = Self.segments
        let colors = (0..<count).map { index in
            Self.color(
                at: (Double(index) + 0.5) / Double(count), time: time, palette: palette)
        }
        return ZStack {
            ForEach(Self.layers.indices, id: \.self) { layerIndex in
                let layer = Self.layers[layerIndex]
                ZStack {
                    ForEach(0..<count, id: \.self) { index in
                        // 조각을 조금씩 겹쳐 이음새에 틈이 생기지 않게 한다.
                        shape.trim(
                            from: max(0, Double(index) / Double(count) - 0.002),
                            to: min(1, Double(index + 1) / Double(count) + 0.002)
                        )
                        .stroke(
                            colors[index],
                            style: StrokeStyle(
                                lineWidth: lineWidth * layer.width * (0.4 + 0.6 * level),
                                lineCap: index == 0 || index == count - 1 ? .round : .butt,
                                lineJoin: .round))
                    }
                }
                .blur(radius: layer.blur)
                .opacity(layer.opacity * level * strength)
            }
        }
    }

    /// 밝기 곡선(0...1). 짧게 차오르고, 마지막 40% 동안 부드럽게 사라진다.
    static func envelope(_ progress: Double) -> Double {
        let rise = min(progress / 0.12, 1)
        let fall = progress > 0.6 ? (1 - progress) / 0.4 : 1
        let value = min(rise, fall)
        // 끝을 부드럽게(ease in-out).
        return value * value * (3 - 2 * value)
    }

    /// 테두리 위치 `position`(0...1, 경로 길이 비율)의 색. 색은 처음과 끝이 이어지는 고리로 섞이고,
    /// 시간이 지나면 테두리를 따라 같은 속도로 흐른다. 색마다 자리가 살짝 흔들려 단조롭지 않다.
    static func color(at position: Double, time: Double, palette: NotchGlowPalette) -> Color {
        let colors = palette.colors.map(Self.nsColor)
        let count = Double(colors.count)
        // 테두리 전체에 색 고리가 0.85바퀴만 보여 색 사이가 넓고, 초당 0.3바퀴 천천히 흐른다.
        let wobble = 0.03 * sin(time * 1.6 + position * 5)
        var cycle = (position * 0.85 - time * 0.3 + wobble) * count
        cycle -= (cycle / count).rounded(.down) * count
        let lower = Int(cycle.rounded(.down)) % colors.count
        let upper = (lower + 1) % colors.count
        // 직선으로 섞는다. 곡선(smoothstep)으로 섞으면 색마다 평평한 구간과 급한 구간이 생겨 오히려 경계가 보인다.
        let fraction = cycle - cycle.rounded(.down)
        return Color(
            nsColor: colors[lower].blended(withFraction: fraction, of: colors[upper])
                ?? colors[lower])
    }

    private static func nsColor(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private struct GlowClip<S: Shape>: ViewModifier {
    let shape: S
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn { content.clipShape(shape) } else { content }
    }
}
