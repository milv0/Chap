import Foundation

/// Chap 마스코트(아기 물범)의 24×12 픽셀 스프라이트. 이미지 에셋 대신 문자 격자로 두어
/// 해상도와 무관하게 선명하게 그리고, 형태를 테스트로 고정한다.
/// 원본 그림은 proper-pixel-art(MIT)로 실제 격자를 복원한 뒤 손으로 단순화했다.
public enum ChapMascot {
    /// 픽셀 종류. 투명 칸은 격자에서 `.`이며 여기에는 없다.
    public enum Ink: Equatable, Sendable {
        /// 윤곽선과 눈·입(`o`, `e`).
        case outline
        /// 흰 몸통(`w`).
        case body
        /// 배 아래 그림자(`s`).
        case shade
    }

    /// 한 픽셀. 좌상단이 (0, 0)이다.
    public struct Pixel: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public let ink: Ink
    }

    /// 머리가 왼쪽, 꼬리가 오른쪽인 엎드린 물범.
    public static let rows: [String] = [
        ".....oooo...............",
        "....owwwwoo.............",
        "...owwwwwwwo............",
        "..owwwwwwwwwoooo........",
        "..owewwewwwwwwwwoo......",
        "..owwwwwwwwwwwwwwwo.....",
        "..owwoowwwwwwwwwwwwo..oo",
        ".oswwwwwwwwwwwwwwwwwoowo",
        "oswswwwwwwwwwwwwwwwwwwo.",
        "ossoossswwwwwwwwsssssswo",
        ".oo..oosssssssssooooooo.",
        ".......ooooooooo........",
    ]

    public static let width = 24
    public static let height = 12

    /// 투명이 아닌 모든 픽셀.
    public static let pixels: [Pixel] = rows.enumerated().flatMap { y, row in
        row.enumerated().compactMap { x, ch -> Pixel? in
            switch ch {
            case "o", "e": return Pixel(x: x, y: y, ink: .outline)
            case "w": return Pixel(x: x, y: y, ink: .body)
            case "s": return Pixel(x: x, y: y, ink: .shade)
            default: return nil
            }
        }
    }

    /// 노치 상단 띠에서 한 픽셀의 크기(pt). 1.5pt는 Retina에서 정확히 3픽셀이라 흐려지지 않는다.
    public static let stripPixelSize: CGFloat = 1.5
}
