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
}
