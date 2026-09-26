import CoreGraphics
import Testing

@testable import Chap

@Suite("NotchContrastPolicy")
struct NotchContrastPolicyTests {
    @Test("relative luminance follows the WCAG formula")
    func luminanceMatchesWCAG() {
        #expect(NotchContrastPolicy.relativeLuminance(hex: "#000000") == 0)
        #expect(abs(NotchContrastPolicy.relativeLuminance(hex: "#FFFFFF") - 1) < 0.001)
        // Chap 액센트 블루는 어두운 쪽이지만 순검정보다는 밝다.
        let accent = NotchContrastPolicy.relativeLuminance(hex: "#3664FF")
        #expect(accent > 0.05)
        #expect(accent < 0.3)
    }

    @Test("contrast ratio is symmetric and bounded")
    func contrastRatioBasics() {
        let maxRatio = NotchContrastPolicy.contrastRatio(
            luminance: 0, against: 1)
        #expect(abs(maxRatio - 21) < 0.01)
        #expect(
            NotchContrastPolicy.contrastRatio(luminance: 1, against: 0) == maxRatio)
    }

    @Test("black backgrounds keep the accent tint for icons")
    func blackKeepsAccent() {
        // 순검정 위에서 액센트는 3:1 이상이라 그대로 쓴다.
        #expect(NotchContrastPolicy.usesAccentForeground(backgroundHex: "#000000"))
    }

    @Test("accent-colored backgrounds drop the accent tint")
    func accentBackgroundDropsAccent() {
        // 배경이 액센트와 같으면 대비가 1:1에 가까워 흰색으로 바꿔야 한다.
        #expect(NotchContrastPolicy.usesAccentForeground(backgroundHex: "#3664FF") == false)
    }

    @Test("secondary text opacity rises on lighter backgrounds")
    func secondaryOpacityAdapts() {
        let onBlack = NotchContrastPolicy.secondaryTextOpacity(backgroundHex: "#000000")
        let onBlue = NotchContrastPolicy.secondaryTextOpacity(backgroundHex: "#3664FF")

        #expect(onBlue > onBlack)
        #expect(onBlack >= 0.6)
        #expect(onBlue <= 1)
    }
    @Test("foreground switches to dark on light custom colors")
    func foregroundSwitchesForLuminance() {
        #expect(NotchContrastPolicy.usesDarkForeground(backgroundHex: "#FFFFFF"))
        #expect(NotchContrastPolicy.usesDarkForeground(backgroundHex: "#F2F2F2"))
        #expect(NotchContrastPolicy.usesDarkForeground(backgroundHex: "#000000") == false)
        #expect(NotchContrastPolicy.usesDarkForeground(backgroundHex: "#3664FF") == false)
    }
}
