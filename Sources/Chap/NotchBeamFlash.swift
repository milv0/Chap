import Cocoa
import SwiftUI

/// Keep Awake나 Timer가 도는 동안, 하드웨어 노치 둘레가 Apple Intelligence처럼 빛난다(`IntelligenceGlow`).
///
/// 노치가 접혀 있어도(메뉴·다이얼 어디서 켜든) 보이도록 노치 주변에 투명 창을 띄운다(`setSteady`).
/// 켜면 서서히 나타나 색이 계속 흐르고, 둘 다 끝나면 서서히 사라진다. 설정에서 색을 바꿀 때는 1.8초만 빛낸다(`show`).
/// 마우스를 가로채지 않고 키 포커스를 가져가지 않는다. 노치가 없는 화면, 동작 줄이기에서는 띄우지 않는다.
/// 모든 호출은 메인 스레드에서 한다.
enum NotchBeamFlash {
    /// 한 번 빛나는 창(설정에서 켜거나 색을 바꿀 때 미리 보기).
    private static var flashWindow: NSWindow?
    private static var flashToken = 0
    /// Keep Awake·Timer가 도는 동안 계속 켜 두는 창과 그 안의 빛.
    private static var steadyWindow: NSWindow?
    private static var steadyGlow: GlowLayerView?
    private static var steadyOutline: NSRect?
    /// 데스크탑(Space)이 바뀌면 빛을 새 데스크탑으로 옮겨 다시 나타낸다.
    private static var spaceObserver: NSObjectProtocol?
    private static var spaceToken = 0

    /// 한 번 빛날 때 보이는 시간(초).
    static let duration: Double = 1.8
    /// 켜고 끌 때 창이 나타나고 사라지는 시간(초).
    private static let fadeDuration: TimeInterval = 0.4
    /// 빛이 노치 테두리에서 떨어진 거리. 노치 안쪽은 픽셀이 없어 바깥에 그린다.
    private static let gap: CGFloat = 2.5
    /// 번짐이 창 경계에서 잘리지 않도록 두는 여백.
    private static let margin: CGFloat = 28

    /// 계속 켜 둔 빛이 보이는 중인지. 그동안 설정의 미리 보기는 따로 띄우지 않는다.
    static var isSteadyVisible: Bool { steadyWindow != nil }

    /// 한 번 빛낸다(설정에서 켜거나 색을 바꿀 때 미리 보기): 서서히 나타나 머물다 사라진다.
    static func show(palette: NotchGlowPalette) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            let screen = NotchLauncherController.notchScreen()
        else { return }
        flashToken += 1
        let current = flashToken
        flashWindow?.orderOut(nil)
        let notch = NotchLauncherController.notchRect(on: screen)
        let flash = makeWindow(around: notch)
        flash.contentView = makeGlowView(outlineSize: notch.size, palette: palette)
        flash.alphaValue = 0
        flash.orderFrontRegardless()
        flashWindow = flash
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            flash.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.6) {
            guard current == flashToken else { return }
            NSAnimationContext.runAnimationGroup(
                { context in
                    context.duration = 0.6
                    flash.animator().alphaValue = 0
                },
                completionHandler: {
                    guard current == flashToken else { return }
                    flash.orderOut(nil)
                    flash.contentView = nil
                    flashWindow = nil
                })
        }
    }

    /// Keep Awake·Timer가 도는 동안 `outline`(노치와 옆 배지를 합친 검정 띠, 화면 좌표) 둘레를 계속 빛낸다.
    /// `palette`가 nil이면 끈다(부드럽게 사라진다). 같은 색·같은 자리면 아무 일도 하지 않으니 상태가 바뀔 때마다
    /// 불러도 된다.
    static func setSteady(_ palette: NotchGlowPalette?, around outline: NSRect?) {
        guard let palette, let outline,
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            hideSteady()
            return
        }
        if let glow = steadyGlow, steadyOutline == outline {
            // 색만 바뀌었다. 마스크는 그대로 두고 그라데이션만 바꾼다.
            glow.style.palette = palette
            return
        }
        let frame = windowFrame(around: outline)
        let glow = makeGlowView(outlineSize: outline.size, palette: palette)
        steadyOutline = outline
        steadyGlow = glow
        // 이미 떠 있으면(배지가 붙어 자리가 바뀜) 내용만 바꾸고, 처음이면 서서히 나타낸다.
        if let existing = steadyWindow {
            existing.setFrame(frame, display: false)
            existing.contentView = glow
            existing.alphaValue = 1
            return
        }
        let window = makeWindow(around: outline)
        // 모든 데스크탑에 고정해 두면 데스크탑을 넘기는 동안 새 화면보다 빛 상자가 먼저 떠 보인다.
        // 그래서 지금 데스크탑에만 두고(넘기면 이전 화면과 함께 밀려난다), 도착하면 새 데스크탑으로 옮겨 다시 켠다.
        window.collectionBehavior = [.moveToActiveSpace, .ignoresCycle]
        window.contentView = glow
        window.alphaValue = 0
        window.orderFrontRegardless()
        steadyWindow = window
        observeSpaceChanges()
        fadeIn(window)
    }

    private static func fadeIn(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            window.animator().alphaValue = 1
        }
    }

    private static func observeSpaceChanges() {
        guard spaceObserver == nil else { return }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            moveToActiveSpace()
        }
    }

    /// 새 데스크탑에 도착한 뒤: 이전 데스크탑의 빛을 거두고, 넘기는 움직임이 끝날 즈음 새 데스크탑에 서서히 켠다.
    private static func moveToActiveSpace() {
        guard let window = steadyWindow else { return }
        spaceToken += 1
        let current = spaceToken
        window.alphaValue = 0
        window.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard current == spaceToken, steadyWindow === window else { return }
            window.orderFrontRegardless()
            fadeIn(window)
        }
    }

    /// 계속 켜 둔 빛을 서서히 끈다. 사라지는 사이 다시 켜지면 새 창을 따로 띄우고, 이 창만 닫는다.
    private static func hideSteady() {
        guard let window = steadyWindow else { return }
        steadyWindow = nil
        steadyGlow = nil
        steadyOutline = nil
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = fadeDuration
                window.animator().alphaValue = 0
            },
            completionHandler: {
                window.orderOut(nil)
                // 다 숨긴 창이 애니메이션을 계속 돌리지 않게 내용을 뗀다.
                window.contentView = nil
            })
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
    static func makeGlowView(outlineSize: CGSize, palette: NotchGlowPalette) -> GlowLayerView {
        let outline = CGSize(width: outlineSize.width + gap * 2, height: outlineSize.height + gap)
        let shape = NotchOutlineShape(
            outline: outline, cornerRadius: NotchGeometry.badgeCornerRadius + gap)
        let view = GlowLayerView(style: .init(palette: palette)) { rect in
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
