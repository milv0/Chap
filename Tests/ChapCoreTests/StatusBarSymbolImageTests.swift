import Cocoa
import Testing

@testable import Chap

@Suite("StatusBarSymbolImage")
struct StatusBarSymbolImageTests {
    @Test func boltFillReturnsNonNilImage() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "bolt.fill", accessibilityDescription: "Chap")

        #expect(image != nil)
    }

    @Test func boltFillHasExplicit22x22Size() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "bolt.fill", accessibilityDescription: "Chap")

        #expect(image?.size == NSSize(width: 22, height: 22))
    }

    @Test func boltFillIsTemplate() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "bolt.fill", accessibilityDescription: "Chap")

        #expect(image?.isTemplate == true)
    }

    @Test func warningBadgeReturnsNonNilImage() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "bolt.trianglebadge.exclamationmark",
            accessibilityDescription: "Chap – accessibility required")

        #expect(image != nil)
    }

    @Test func warningBadgeHasExplicit22x22Size() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "bolt.trianglebadge.exclamationmark",
            accessibilityDescription: "Chap – accessibility required")

        #expect(image?.size == NSSize(width: 22, height: 22))
    }

    @Test func warningBadgeIsTemplate() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "bolt.trianglebadge.exclamationmark",
            accessibilityDescription: "Chap – accessibility required")

        #expect(image?.isTemplate == true)
    }

    @Test func invalidSymbolNameReturnsNil() {
        let image = AppDelegate.statusBarSymbolImage(
            name: "nonexistent.symbol.name.xyz",
            accessibilityDescription: nil)

        #expect(image == nil)
    }

    @Test func consecutiveCallsProduceSameGeometry() {
        let first = AppDelegate.statusBarSymbolImage(
            name: "bolt.fill", accessibilityDescription: "Chap")
        let second = AppDelegate.statusBarSymbolImage(
            name: "bolt.fill", accessibilityDescription: "Chap")

        #expect(first?.size == second?.size)
    }
}

// MARK: - Isolated copy regression tests

@Suite("IsolatedCopyImageTests")
struct IsolatedCopyImageTests {
    /// Helper: creates a 1×1 pixel NSImage at the given logical size.
    private func syntheticImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    @Test func isolatedCopyReturnsNonNilForValidSource() {
        let source = syntheticImage(size: NSSize(width: 64, height: 64))
        let result = AppDelegate.isolatedCopy(
            of: source, size: NSSize(width: 22, height: 22))

        #expect(result != nil)
    }

    @Test func isolatedCopyReturnsNilForNilSource() {
        let result = AppDelegate.isolatedCopy(
            of: nil, size: NSSize(width: 22, height: 22))

        #expect(result == nil)
    }

    @Test func isolatedCopyAppliesRequestedSize() {
        let source = syntheticImage(size: NSSize(width: 64, height: 64))
        let result = AppDelegate.isolatedCopy(
            of: source, size: NSSize(width: 14, height: 14))

        #expect(result?.size == NSSize(width: 14, height: 14))
    }

    @Test func isolatedCopyDoesNotMutateSourceSize() {
        let source = syntheticImage(size: NSSize(width: 64, height: 64))
        _ = AppDelegate.isolatedCopy(
            of: source, size: NSSize(width: 14, height: 14))

        #expect(source.size == NSSize(width: 64, height: 64))
    }

    @Test func isolatedCopyProducesDistinctInstance() {
        let source = syntheticImage(size: NSSize(width: 64, height: 64))
        let result = AppDelegate.isolatedCopy(
            of: source, size: NSSize(width: 22, height: 22))

        #expect(result !== source)
    }

    /// Regression: creating a 14×14 menu-preview copy must not shrink a
    /// previously-created 22×22 status-bar copy from the same source.
    @Test func menuPreviewCopyCannotMutateStatusBarCopy() {
        let sharedSource = syntheticImage(size: NSSize(width: 64, height: 64))

        // Simulate status bar icon creation (22×22)
        let statusBarIcon = AppDelegate.isolatedCopy(
            of: sharedSource, size: NSSize(width: 22, height: 22))

        // Simulate menu preview icon creation (14×14) from the same source
        let menuPreviewIcon = AppDelegate.isolatedCopy(
            of: sharedSource, size: NSSize(width: 14, height: 14))

        // The status bar icon must still be 22×22 after menu preview creation
        #expect(statusBarIcon?.size == NSSize(width: 22, height: 22))
        // The menu preview must be 14×14
        #expect(menuPreviewIcon?.size == NSSize(width: 14, height: 14))
        // The original source must be unchanged
        #expect(sharedSource.size == NSSize(width: 64, height: 64))
    }

    @Test func accentTintedImagePreservesGeometryAndIsNonTemplate() {
        let source = syntheticImage(size: NSSize(width: 22, height: 22))

        let result = AppDelegate.accentTintedStatusBarImage(
            source, accessibilityDescription: "Chap – Keep Awake active")

        #expect(result?.size == NSSize(width: 22, height: 22))
        #expect(result?.isTemplate == false)
        #expect(result?.accessibilityDescription == "Chap – Keep Awake active")
    }
    /// Regression: two isolated copies from the same source are fully independent.
    @Test func twoCopiesFromSameSourceAreIndependent() {
        let sharedSource = syntheticImage(size: NSSize(width: 48, height: 48))

        let copyA = AppDelegate.isolatedCopy(
            of: sharedSource, size: NSSize(width: 22, height: 22))
        let copyB = AppDelegate.isolatedCopy(
            of: sharedSource, size: NSSize(width: 14, height: 14))

        // Mutating copyB after creation must not affect copyA
        copyB?.size = NSSize(width: 8, height: 8)

        #expect(copyA?.size == NSSize(width: 22, height: 22))
        #expect(copyB?.size == NSSize(width: 8, height: 8))
    }

    /// 물범 아이콘을 그린 비트맵 (위가 y=0).
    private func sealBitmap(scale: Int) throws -> NSBitmapImageRep {
        let image = AppDelegate.sealStatusBarImage()
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(image.size.width) * scale,
                pixelsHigh: Int(image.size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0))
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    @Test("on Retina the eyes and mouth stay two pixels while the outline thickens")
    func faceStaysThin() throws {
        let rep = try sealBitmap(scale: 2)
        // 26×22 캔버스에서 격자의 원점은 (1, 5)pt. Retina에서 칸 (x, y)는 픽셀 (2(x+1), 2(y+5))부터 2×2.
        func alpha(cellX: Int, cellY: Int, dx: Int, dy: Int) -> CGFloat {
            rep.colorAt(x: 2 * (cellX + 1) + dx, y: 2 * (cellY + 5) + dy)?.alphaComponent ?? 0
        }
        for face in ChapMascot.menuBarFace {
            let (x, y) = (face[0], face[1])
            #expect(alpha(cellX: x, cellY: y, dx: 1, dy: 1) > 0.99, "face \(face) is drawn")
            // 오른쪽 이웃이 몸통(빈 칸)인 얼굴 칸은 그 자리가 비어 있어야 한다 = 늘리지 않았다.
            let rightIsEmpty = !ChapMascot.menuBarOutline.contains { $0.x == x + 1 && $0.y == y }
            if rightIsEmpty {
                #expect(alpha(cellX: x, cellY: y, dx: 2, dy: 0) < 0.01, "face \(face) stays thin")
            }
        }
        // 윤곽 칸 하나(머리 꼭대기 (5, 0))는 오른쪽 아래 1픽셀이 더 칠해져 있다.
        #expect(alpha(cellX: 8, cellY: 0, dx: 2, dy: 2) > 0.99)
    }

    /// 물범 아이콘을 2배(Retina)로 그려 픽셀을 센다.
    private func sealPixels(scale: Int) throws -> (opaque: Int, partial: Int) {
        let image = AppDelegate.sealStatusBarImage()
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(image.size.width) * scale,
                pixelsHigh: Int(image.size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0))
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        var opaque = 0
        var partial = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let alpha = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if alpha > 0.99 { opaque += 1 } else if alpha > 0.01 { partial += 1 }
            }
        }
        return (opaque, partial)
    }

    @Test("on Retina the seal's lines are three pixels thick and stay crisp")
    func sealLinesAreThickAndCrisp() throws {
        let retina = try sealPixels(scale: 2)
        // 칸마다 2×2픽셀이던 선이 3×3픽셀이 된다(겹침이 있어 정확히 9/4배는 아니다).
        let oneCellOnly = ChapMascot.menuBarOutline.count * 4
        #expect(retina.opaque > oneCellOnly * 3 / 2)
        // 반투명 픽셀이 없다 = 경계가 장치 픽셀에 맞아 흐려지지 않는다.
        #expect(retina.partial == 0)
    }

    @Test("on a 1x screen the seal keeps one-pixel lines rather than going blurry")
    func sealStaysCrispAt1x() throws {
        let standard = try sealPixels(scale: 1)
        #expect(standard.opaque == ChapMascot.menuBarOutline.count)
        #expect(standard.partial == 0)
    }
}
