import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Core Animation glow

/// Apple Intelligence(Siri) 테두리처럼 도형 둘레 전체가 여러 색으로 빛나고, 색이 천천히 흐르는 빛.
///
/// 오픈소스 재현들(IntelligenceGlow, AppleIntelligenceGlowEffect, MIT)의 겹치는 띠 구성(두께·흐림을 달리한
/// 4겹)을 참고했다. 그 라이브러리들은 SwiftUI로 매 프레임 다시 그리지만, 여기서는 그리기를 모두 Core Animation에
/// 맡긴다:
/// - 테두리 모양과 번짐은 처음 한 번만 그린 알파 마스크 이미지다(`makeMask`, 크기·배율이 바뀔 때만 다시 그린다).
/// - 색은 가로 그라데이션 층(`CAGradientLayer`)이고, 그 층을 옆으로 미는 반복 애니메이션 하나로 색이 흐른다.
///   매 프레임 합성은 GPU에서 시스템이 하므로 Chap 프로세스는 거의 아무 일도 하지 않는다.
/// 색은 가로 위치를 따라 고르게 칠한다. 각도 그라데이션은 납작한 노치 아랫변 가운데에 색이 몰려 끊겨 보였다.
/// 동작 줄이기가 켜져 있으면 색이 흐르지 않고 멈춘 채 빛난다.
final class GlowLayerView: NSView {
    struct Style: Equatable {
        var palette: NotchGlowPalette = .colorful
        /// 가장 안쪽 띠 두께(pt). 바깥 띠는 이 값의 배수다.
        var lineWidth: CGFloat = 2.5
        /// 빛을 도형 안쪽에만 둔다(도커). 하드웨어 노치처럼 안쪽에 픽셀이 없는 도형은 끄고 바깥으로 번지게 한다.
        var clipsToPath = false
        /// 빛을 도형 바깥에만 둔다(펼친 도커 둘레: 안쪽에는 칸 내용이 있다).
        var clipsOutsidePath = false
        /// 위에서 이 높이까지는 빛을 가리고(화면 꼭대기·메뉴 막대에 붙은 윗변), 그 아래 `topFadeLength`만큼 서서히 드러낸다.
        var topFadeInset: CGFloat?
        var topFadeLength: CGFloat = 16
    }

    /// 겹치는 띠: (두께 배수, 흐림, 불투명도). 안쪽은 또렷하고 바깥은 넓게 번진다.
    static let layers: [(width: CGFloat, blur: CGFloat, opacity: CGFloat)] = [
        (1, 1, 0.9), (2, 4, 0.8), (3.2, 9, 0.6), (5, 16, 0.45),
    ]
    /// 뷰 폭에 색 고리가 이 비율만큼 보인다(0.85바퀴). 색 사이가 넓어 경계가 보이지 않는다.
    static let cycleFraction: CGFloat = 0.85
    /// 색 고리가 한 바퀴 흐르는 시간(초).
    static let flowDuration: CFTimeInterval = 3.3

    /// 도형 테두리(SwiftUI 좌표: 왼쪽 위 원점)를 돌려준다. 크기가 바뀔 때마다 다시 묻는다.
    var pathProvider: (CGRect) -> CGPath {
        didSet {
            needsRebuild = true
            needsLayout = true
        }
    }
    var style: Style {
        didSet {
            guard style != oldValue else { return }
            needsRebuild = true
            needsLayout = true
        }
    }
    /// 빛이 이 도형(SwiftUI 좌표) 밖으로 나가지 않게 한다. 도커 검정 띠의 빛이 도커 위쪽 좌우 꼭짓점에서 도커 밖으로
    /// 번지지 않게 도커 모양을 준다. nil이면 뷰 경계만.
    var containerProvider: ((CGRect) -> CGPath)? {
        didSet {
            needsRebuild = true
            needsLayout = true
        }
    }
    /// 0...1. 전체 밝기.
    var strength: CGFloat = 1 {
        didSet { clipLayer.opacity = Float(strength) }
    }

    private let clipLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CALayer()
    private var needsRebuild = true
    private var builtSize: CGSize = .zero
    private var builtScale: CGFloat = 0
    private static let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let flowKey = "ChapGlowFlow"

    init(style: Style, pathProvider: @escaping (CGRect) -> CGPath) {
        self.style = style
        self.pathProvider = pathProvider
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        clipLayer.mask = maskLayer
        clipLayer.addSublayer(gradientLayer)
        layer?.addSublayer(clipLayer)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// 빛은 장식이라 마우스를 받지 않는다.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsRebuild = true
        rebuildIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 창에서 떨어지면 애니메이션이 사라지므로 다시 붙을 때 다시 건다.
        guard window != nil else { return }
        needsRebuild = true
        rebuildIfNeeded()
    }

    private var scale: CGFloat { window?.backingScaleFactor ?? 2 }

    private func rebuildIfNeeded() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        guard needsRebuild || size != builtSize || scale != builtScale else { return }
        needsRebuild = false
        builtSize = size
        builtScale = scale
        rebuild(size: size)
    }

    /// 도형 좌표(왼쪽 위 원점)를 이 뷰(왼쪽 아래 원점)로 옮긴 테두리.
    private func flippedPath(in size: CGSize) -> CGPath {
        flipped(pathProvider, in: size)
    }

    private func flippedContainer(in size: CGSize) -> CGPath? {
        containerProvider.map { flipped($0, in: size) }
    }

    private func flipped(_ provider: (CGRect) -> CGPath, in size: CGSize) -> CGPath {
        var flip = CGAffineTransform(translationX: 0, y: size.height).scaledBy(x: 1, y: -1)
        let path = provider(CGRect(origin: .zero, size: size))
        return path.copy(using: &flip) ?? path
    }

    private func rebuild(size: CGSize) {
        let path = flippedPath(in: size)
        let period = size.width / Self.cycleFraction
        let colors = style.palette.colors.map(Self.cgColor)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clipLayer.frame = bounds
        clipLayer.opacity = Float(strength)
        maskLayer.frame = bounds
        maskLayer.contentsScale = scale
        maskLayer.contents = Self.makeMask(
            path: path, container: flippedContainer(in: size), size: size, scale: scale,
            style: style)
        // 그라데이션은 왼쪽으로 한 고리 더 깔아 두고 오른쪽으로 한 고리만큼 밀어, 미는 동안에도 뷰 전체를 덮는다.
        let periods = Int(((size.width + 2 * period) / period).rounded(.up))
        let total = CGFloat(periods) * period
        var stops: [CGColor] = []
        var locations: [NSNumber] = []
        for index in 0..<periods {
            for (offset, color) in colors.enumerated() {
                stops.append(color)
                let along = (CGFloat(index) + CGFloat(offset) / CGFloat(colors.count)) * period
                locations.append(NSNumber(value: Double(along / total)))
            }
        }
        stops.append(colors[0])
        locations.append(1)
        gradientLayer.colors = stops
        gradientLayer.locations = locations
        gradientLayer.anchorPoint = .zero
        gradientLayer.bounds = CGRect(x: 0, y: 0, width: total, height: size.height)
        gradientLayer.position = CGPoint(x: -period, y: 0)
        CATransaction.commit()
        restartFlow(period: period)
    }

    private func restartFlow(period: CGFloat) {
        gradientLayer.removeAnimation(forKey: Self.flowKey)
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let flow = CABasicAnimation(keyPath: "position.x")
        flow.fromValue = -period
        flow.toValue = 0
        flow.duration = Self.flowDuration
        flow.timingFunction = CAMediaTimingFunction(name: .linear)
        flow.repeatCount = .infinity
        flow.isRemovedOnCompletion = false
        gradientLayer.add(flow, forKey: Self.flowKey)
    }

    // MARK: Mask

    /// 테두리 띠 4겹을 흰색으로 그리고 흐려서 합친 알파 마스크. 그라데이션은 이 모양 안에서만 보인다.
    static func makeMask(
        path: CGPath, container: CGPath? = nil, size: CGSize, scale: CGFloat, style: Style
    ) -> CGImage? {
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        let space = Self.colorSpace
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard width > 0, height > 0,
            let output = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: info)
        else { return nil }
        var toPixels = CGAffineTransform(scaleX: scale, y: scale)
        let pixelPath = path.copy(using: &toPixels) ?? path
        let pixelRect = CGRect(x: 0, y: 0, width: width, height: height)
        if let container, let pixelContainer = container.copy(using: &toPixels) {
            output.addPath(pixelContainer)
            output.clip()
        }
        if style.clipsToPath {
            output.addPath(pixelPath)
            output.clip()
        } else if style.clipsOutsidePath {
            output.addRect(pixelRect)
            output.addPath(pixelPath)
            output.clip(using: .evenOdd)
        }
        for layer in layers {
            guard
                let stroke = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: info)
            else { continue }
            stroke.addPath(pixelPath)
            stroke.setLineWidth(style.lineWidth * layer.width * scale)
            stroke.setLineCap(.round)
            stroke.setLineJoin(.round)
            stroke.setStrokeColor(CGColor(gray: 1, alpha: 1))
            stroke.strokePath()
            guard var image = stroke.makeImage() else { continue }
            if layer.blur > 0 {
                let filter = CIFilter.gaussianBlur()
                filter.inputImage = CIImage(cgImage: image).clampedToExtent()
                filter.radius = Float(layer.blur * scale)
                if let blurred = filter.outputImage?.cropped(to: pixelRect),
                    let rendered = imageContext.createCGImage(blurred, from: pixelRect)
                {
                    image = rendered
                }
            }
            output.setAlpha(layer.opacity)
            output.draw(image, in: pixelRect)
        }
        if let inset = style.topFadeInset {
            // 알파를 곱해(destinationIn) 위쪽을 가리고 그 아래로 서서히 드러낸다.
            let top = (CGFloat(height) - inset * scale) / CGFloat(height)
            let bottom = (CGFloat(height) - (inset + style.topFadeLength) * scale) / CGFloat(height)
            let fade = CGGradient(
                colorsSpace: space,
                colors: [
                    CGColor(colorSpace: space, components: [0, 0, 0, 1]),
                    CGColor(colorSpace: space, components: [0, 0, 0, 1]),
                    CGColor(colorSpace: space, components: [0, 0, 0, 0]),
                    CGColor(colorSpace: space, components: [0, 0, 0, 0]),
                ].compactMap { $0 } as CFArray,
                locations: [0, max(bottom, 0), min(max(top, 0), 1), 1])
            if let fade {
                output.setAlpha(1)
                output.setBlendMode(.destinationIn)
                output.drawLinearGradient(
                    fade, start: .zero, end: CGPoint(x: 0, y: height), options: [])
            }
        }
        return output.makeImage()
    }

    /// 마스크·그라데이션·색이 모두 같은 색 공간을 쓴다(CGGradient는 색 공간이 다르면 만들어지지 않는다).
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    static func cgColor(_ hex: UInt32) -> CGColor {
        CGColor(
            colorSpace: colorSpace,
            components: [
                CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                CGFloat(hex & 0xFF) / 255, 1,
            ]) ?? CGColor(gray: 0.5, alpha: 1)
    }

    // MARK: Snapshot

    /// 지금 모습을 한 장으로 그린다(렌더 도구·문서용). 화면에는 Core Animation이 그리므로 실행 중에는 쓰지 않는다.
    func snapshot(scale: CGFloat = 2) -> CGImage? {
        let size = bounds.size
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        let space = Self.colorSpace
        guard width > 0, height > 0,
            let mask = Self.makeMask(
                path: flippedPath(in: size), container: flippedContainer(in: size), size: size,
                scale: scale, style: style),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let colors = style.palette.colors.map(Self.cgColor)
        let period = size.width / Self.cycleFraction * scale
        var stops = colors + [colors[0]]
        stops.append(contentsOf: colors)
        // 두 고리(period × 2)에 걸쳐 0...1로 고르게 둔다.
        let locations = stops.indices.map { CGFloat($0) / CGFloat(stops.count - 1) }
        guard
            let gradient = CGGradient(
                colorsSpace: space, colors: stops as CFArray, locations: locations)
        else { return nil }
        context.setAlpha(CGFloat(strength))
        context.drawLinearGradient(
            gradient, start: .zero, end: CGPoint(x: period * 2, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.setAlpha(1)
        context.setBlendMode(.destinationIn)
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

// MARK: - SwiftUI

/// SwiftUI 안에서 쓰는 `GlowLayerView`(노치 도커의 Drop here 레이어). 보일 때만 두므로 호출하는 쪽이 조건부로 둔다.
struct IntelligenceGlow<S: Shape>: NSViewRepresentable {
    let shape: S
    var palette: NotchGlowPalette = .colorful
    var lineWidth: CGFloat = 2.5
    /// 0...1. 전체 밝기.
    var strength: Double = 1
    var clipsToShape = false
    /// 빛을 도형 바깥에만 둔다(도커 검정 띠: 띠 안에는 노치·아이콘이 있다).
    var clipsOutsideShape = false
    /// 빛이 이 도형 밖으로 나가지 않게 한다(검정 띠 빛을 도커 모양 안에 둔다).
    var container: AnyShape?
    var topFadeInset: CGFloat?

    private var style: GlowLayerView.Style {
        GlowLayerView.Style(
            palette: palette, lineWidth: lineWidth, clipsToPath: clipsToShape,
            clipsOutsidePath: clipsOutsideShape, topFadeInset: topFadeInset)
    }

    func makeNSView(context: Context) -> GlowLayerView {
        let shape = shape
        let view = GlowLayerView(style: style) { rect in shape.path(in: rect).cgPath }
        if let container {
            view.containerProvider = { rect in container.path(in: rect).cgPath }
        }
        view.strength = CGFloat(strength)
        return view
    }

    func updateNSView(_ view: GlowLayerView, context: Context) {
        view.style = style
        view.strength = CGFloat(strength)
    }
}
