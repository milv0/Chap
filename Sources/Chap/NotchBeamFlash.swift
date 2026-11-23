import Cocoa
import SwiftUI

/// 하드웨어 노치 둘레가 Apple Intelligence처럼 한 번 빛난다(`IntelligenceGlow`).
///
/// Keep Awake·Timer가 시작하고 끝날 때, Timer가 다 될 때, 새 파일이 들어올 때, 창이 제자리에 맞춰질 때,
/// 설정에서 색을 바꿀 때 잠깐 빛나고 사라진다. 계속 켜 두지 않는다.
/// 노치가 접혀 있어도 보이도록 노치 주변에 투명 창을 띄운다. 마우스를 가로채지 않고 키 포커스를 가져가지 않는다.
/// 노치가 없는 화면, 동작 줄이기에서는 띄우지 않는다. 모든 호출은 메인 스레드에서 한다.
enum NotchBeamFlash {
    private static var flashWindow: NSWindow?
    private static var flashToken = 0

    /// 빛을 노치 테두리에서 띄우는 거리. 0이면 띠 한가운데가 노치 가장자리에 놓여, 바깥 절반이 노치에 붙어 보인다.
    private static let gap: CGFloat = 0
    /// 노치 빛의 가장 안쪽 띠 두께 기본값(pt). 띠 안쪽 절반은 노치 속에 가려지므로 도커 빛보다 굵게 둔다.
    private static let lineWidth: CGFloat = 4
    /// 번짐이 창 경계에서 잘리지 않도록 두는 여백. 가장 바깥 띠(두께 × 5의 절반)와 흐림(16pt)을 담는다.
    private static let margin: CGFloat = 36

    /// 한 번 빛낸다: 서서히 나타나 머물다 사라진다. 순간(`moment`)마다 길이와 굵기가 다르다.
    /// `outline`은 둘레를 빛낼 검정 띠(노치와 옆 배지, 화면 좌표)이고, 없으면 노치만 두른다.
    /// 이미 빛나는 중에 다시 부르면 새 순간으로 바꾼다.
    static func show(
        palette: NotchGlowPalette, moment: NotchGlowMoment = .preview, around outline: NSRect? = nil
    ) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            let screen = NotchLauncherController.notchScreen()
        else { return }
        flashToken += 1
        let current = flashToken
        flashWindow?.orderOut(nil)
        flashWindow?.contentView = nil
        let outline = outline ?? NotchLauncherController.notchRect(on: screen)
        let flash = makeWindow(around: outline)
        flash.contentView = makeGlowView(
            outlineSize: outline.size, palette: palette, lineWidth: CGFloat(moment.lineWidth))
        flash.alphaValue = 0
        flash.orderFrontRegardless()
        flashWindow = flash
        let fadeIn = min(0.25, moment.duration * 0.2)
        let fadeOut = min(0.6, moment.duration * 0.4)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeIn
            flash.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + moment.duration - fadeOut) {
            guard current == flashToken else { return }
            NSAnimationContext.runAnimationGroup(
                { context in
                    context.duration = fadeOut
                    flash.animator().alphaValue = 0
                },
                completionHandler: {
                    guard current == flashToken else { return }
                    flash.orderOut(nil)
                    // 다 숨긴 창이 애니메이션을 계속 돌리지 않게 내용을 뗀다.
                    flash.contentView = nil
                    flashWindow = nil
                })
        }
    }

    private static func windowFrame(around outline: NSRect) -> NSRect {
        NSRect(
            x: outline.minX - margin, y: outline.minY - margin,
            width: outline.width + margin * 2, height: outline.height + margin)
    }

    /// 빛 창. 노치 옆 Drop·Timer 배지와 같은 창(`NotchAuxiliaryWindow`)을 써서 전체 화면 앱으로 갈 때 배지와
    /// 똑같이 숨는다. 배지보다 한 단계 아래에 둬 배지가 빛을 덮고, 마우스는 아래로 흘려 보낸다.
    private static func makeWindow(around outline: NSRect) -> NSWindow {
        let window = NotchAuxiliaryWindow.make(
            frame: windowFrame(around: outline), level: .statusBar)
        window.ignoresMouseEvents = true
        return window
    }

    /// 검정 띠(`outlineSize`) 둘레를 빛내는 뷰. 창 내용 크기에 맞춰 띠를 위쪽 가운데에 놓고, 나머지는 번짐 자리다.
    /// 렌더 도구도 이 뷰의 `snapshot`으로 모습을 그린다.
    static func makeGlowView(
        outlineSize: CGSize, palette: NotchGlowPalette, lineWidth: CGFloat = lineWidth
    ) -> GlowLayerView {
        let outline = CGSize(width: outlineSize.width + gap * 2, height: outlineSize.height + gap)
        let shape = NotchOutlineShape(
            outline: outline, cornerRadius: NotchGeometry.badgeCornerRadius + gap)
        let view = GlowLayerView(style: .init(palette: palette, lineWidth: lineWidth)) { rect in
            shape.path(in: rect).cgPath
        }
        view.frame = NSRect(
            origin: .zero,
            size: CGSize(
                width: outlineSize.width + margin * 2, height: outlineSize.height + margin))
        view.autoresizingMask = [.width, .height]
        return view
    }
}

/// 하드웨어 노치의 테두리: 화면 꼭대기에서 내려와 아래 모서리를 돌아 다시 올라간다.
/// 모서리는 하드웨어 노치·옆 배지와 같은 연속 곡률(.continuous)이라 빛이 모서리에서도 노치에 붙는다.
/// 윗변은 화면 위쪽 바깥(창 밖)에 두어 그리지 않는다. 띠의 안쪽 절반은 픽셀이 없는 노치 속에 들어가 보이지 않는다.
struct NotchOutlineShape: Shape {
    /// 테두리 크기. 그리는 영역의 위쪽 가운데에 놓는다(영역의 나머지는 번짐 자리).
    let outline: CGSize
    let cornerRadius: CGFloat
    /// 윗변을 창 밖으로 올리는 거리. 가장 넓은 번짐(약 25pt)이 창 안으로 내려오지 않을 만큼.
    private static let topOverhang: CGFloat = 40

    func path(in bounds: CGRect) -> Path {
        let rect = CGRect(
            x: bounds.midX - outline.width / 2, y: bounds.minY - Self.topOverhang,
            width: outline.width, height: outline.height + Self.topOverhang)
        let radius = min(cornerRadius, outline.height, rect.width / 2)
        return UnevenRoundedRectangle(
            bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous
        ).path(in: rect)
    }
}
