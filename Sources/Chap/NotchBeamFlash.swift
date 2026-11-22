import Cocoa
import SwiftUI

/// Keep Awake·Timer를 켜는 순간, 하드웨어 노치 둘레가 Apple Intelligence처럼 잠깐 빛난다(`IntelligenceGlow`).
///
/// 노치가 접혀 있어도(메뉴·다이얼 어디서 켜든) 보이도록 노치 주변에 잠깐 투명 창을 띄운다.
/// 둘레 전체가 여러 색으로 차오르고 색이 흐르다 약 1.8초 뒤 사라지며, 그 뒤 창을 닫는다.
/// 마우스를 가로채지 않고 키 포커스를 가져가지 않는다. 노치가 없는 화면, 동작 줄이기에서는 띄우지 않는다.
/// 모든 호출은 메인 스레드에서 한다.
enum NotchBeamFlash {
    private static var window: NSWindow?
    private static var token = 0

    /// 빛이 보이는 시간(초).
    static let duration: Double = 1.8
    /// 빛이 노치 테두리에서 떨어진 거리. 노치 안쪽은 픽셀이 없어 바깥에 그린다.
    private static let gap: CGFloat = 2.5
    /// 번짐이 창 경계에서 잘리지 않도록 두는 여백.
    private static let margin: CGFloat = 28

    static func show(palette: NotchGlowPalette) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            let screen = NotchLauncherController.notchScreen()
        else { return }
        token += 1
        let current = token
        window?.orderOut(nil)

        let notch = NotchLauncherController.notchRect(on: screen)
        let frame = NSRect(
            x: notch.minX - margin, y: notch.minY - margin,
            width: notch.width + margin * 2, height: notch.height + margin)
        let flash = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        flash.level = .statusBar
        flash.isOpaque = false
        flash.backgroundColor = .clear
        flash.hasShadow = false
        flash.ignoresMouseEvents = true
        // NSPanel은 앱이 비활성이면 스스로 숨는다. Chap은 대개 비활성이라 끄지 않으면 보이지 않는다.
        flash.hidesOnDeactivate = false
        flash.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]
        flash.contentView = NSHostingView(
            rootView: makeContent(notchSize: notch.size, startedAt: Date(), palette: palette))
        flash.orderFrontRegardless()
        window = flash

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            guard current == token else { return }
            window?.orderOut(nil)
            window = nil
        }
    }

    /// 창 내용. 렌더 도구가 지나가는 도중의 모습을 그릴 때도 쓴다.
    /// 번짐이 잘리지 않도록 빛은 창 전체 크기의 캔버스에 그리고, 테두리만 노치 자리에 놓는다.
    static func makeContent(
        notchSize: CGSize, startedAt: Date, palette: NotchGlowPalette = .colorful
    ) -> some View {
        let outline = CGSize(width: notchSize.width + gap * 2, height: notchSize.height + gap)
        let canvas = CGSize(
            width: notchSize.width + margin * 2, height: notchSize.height + margin)
        return IntelligenceGlow(
            shape: NotchOutlineShape(
                outline: outline, cornerRadius: NotchGeometry.badgeCornerRadius + gap),
            palette: palette, startedAt: startedAt, duration: duration
        )
        .frame(width: canvas.width, height: canvas.height)
    }
}

/// 하드웨어 노치의 바깥 테두리: 화면 꼭대기에서 내려와 둥근 아래 모서리를 돌아 다시 올라간다.
/// 윗변은 메뉴 막대 끝이라 그리지 않는다.
struct NotchOutlineShape: Shape {
    /// 테두리 크기. 그리는 영역의 위쪽 가운데에 놓는다(영역의 나머지는 번짐 자리).
    let outline: CGSize
    let cornerRadius: CGFloat

    func path(in bounds: CGRect) -> Path {
        let rect = CGRect(
            x: bounds.midX - outline.width / 2, y: bounds.minY, width: outline.width,
            height: outline.height)
        let radius = min(cornerRadius, rect.height, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
