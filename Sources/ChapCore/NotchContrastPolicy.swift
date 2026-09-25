import CoreGraphics

/// 노치 도커 전경색의 가독성 정책.
///
/// Apple Human Interface Guidelines의 대비 기준을 따른다:
/// 텍스트는 최소 4.5:1(7:1 권장), 아이콘 등 비텍스트 요소는 최소 3:1.
/// 사용자가 콘텐츠 박스 색을 자유롭게 고를 수 있으므로, 배경 휘도에 따라
/// 액센트 사용 여부와 보조 텍스트 불투명도를 자동으로 조정한다.
///
/// 참고: https://developer.apple.com/design/human-interface-guidelines/color
public enum NotchContrastPolicy {
    /// 비텍스트(아이콘) 최소 대비.
    public static let nonTextMinimumRatio: Double = 3
    /// Chap 액센트 블루 (DS.accent).
    public static let accentHex = "#3664FF"

    /// WCAG 상대 휘도. sRGB 채널을 선형화해 가중 합한다.
    public static func relativeLuminance(hex: String) -> Double {
        guard let valid = Config.validNotchPanelColorHex(hex),
            let value = UInt32(valid.dropFirst(), radix: 16)
        else { return 0 }
        func channel(_ raw: UInt32) -> Double {
            let c = Double(raw) / 255
            return c <= 0.040_45 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((value >> 16) & 0xFF)
            + 0.7152 * channel((value >> 8) & 0xFF)
            + 0.0722 * channel(value & 0xFF)
    }

    /// 두 휘도의 대비비 (1~21).
    public static func contrastRatio(luminance: Double, against other: Double) -> Double {
        let lighter = max(luminance, other)
        let darker = min(luminance, other)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// 아이콘에 액센트 색을 쓸 수 있는지. 배경과의 대비가 HIG 비텍스트
    /// 최소치(3:1) 미달이면 흰색으로 대체해야 한다.
    public static func usesAccentForeground(backgroundHex: String) -> Bool {
        let background = relativeLuminance(hex: backgroundHex)
        let accent = relativeLuminance(hex: accentHex)
        return contrastRatio(luminance: accent, against: background) >= nonTextMinimumRatio
    }

    /// 보조 텍스트(섹션 라벨 등) 흰색 불투명도. 배경이 밝을수록 흰색의
    /// 대비가 떨어지므로 불투명도를 올려 4.5:1 쪽으로 끌어올린다.
    public static func secondaryTextOpacity(backgroundHex: String) -> Double {
        interpolatedOpacity(backgroundHex: backgroundHex, dark: 0.65, light: 0.92)
    }

    /// 3차 텍스트(단축키 힌트 등) 흰색 불투명도.
    public static func tertiaryTextOpacity(backgroundHex: String) -> Double {
        interpolatedOpacity(backgroundHex: backgroundHex, dark: 0.45, light: 0.8)
    }

    /// 배경 휘도를 0(순검정)~0.25 구간에서 정규화해 두 값 사이를 보간한다.
    /// 0.25 이상이면 유채색·밝은 배경으로 보고 상한을 쓴다.
    private static func interpolatedOpacity(
        backgroundHex: String, dark: Double, light: Double
    ) -> Double {
        let t = min(relativeLuminance(hex: backgroundHex) / 0.25, 1)
        return dark + (light - dark) * t
    }
}
