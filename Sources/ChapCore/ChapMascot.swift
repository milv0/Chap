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

    /// 꼬리를 든 프레임. 꼬리 쪽(오른쪽 끝 다섯 칸)만 다르고 나머지는 `rows`와 같다.
    public static let tailUpRows: [String] = [
        ".....oooo...............",
        "....owwwwoo.............",
        "...owwwwwwwo............",
        "..owwwwwwwwwoooo........",
        "..owewwewwwwwwwwoo...oo.",
        "..owwwwwwwwwwwwwwwo.owo.",
        "..owwoowwwwwwwwwwwwoowo.",
        ".oswwwwwwwwwwwwwwwwwwwo.",
        "oswswwwwwwwwwwwwwwwwwwo.",
        "ossoossswwwwwwwwssssssso",
        ".oo..oosssssssssooooooo.",
        ".......ooooooooo........",
    ]

    public static let width = 24
    public static let height = 12

    /// 꼬리 자세.
    public enum Pose: Equatable, Sendable {
        case rest
        case tailUp
    }

    /// 투명이 아닌 모든 픽셀 (쉬는 자세).
    public static let pixels: [Pixel] = pixels(from: rows)

    /// 꼬리를 든 자세의 픽셀.
    public static let tailUpPixels: [Pixel] = pixels(from: tailUpRows)

    public static func pixels(for pose: Pose) -> [Pixel] {
        pose == .rest ? pixels : tailUpPixels
    }

    private static func pixels(from rows: [String]) -> [Pixel] {
        rows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, ch -> Pixel? in
                switch ch {
                case "o", "e": return Pixel(x: x, y: y, ink: .outline)
                case "w": return Pixel(x: x, y: y, ink: .body)
                case "s": return Pixel(x: x, y: y, ink: .shade)
                default: return nil
                }
            }
        }
    }

    /// 꼬리 까딱 한 번: 들고, 내리고, 한 번 더 들고, 내린다.
    public static let flickSequence: [Pose] = [.tailUp, .rest, .tailUp, .rest]

    /// 까딱 한 프레임의 길이(초).
    public static let flickFrameDuration: Double = 0.14

    /// 노치를 연 뒤 첫 까딱까지의 지연(초). 펼침 애니메이션이 끝난 뒤 반긴다.
    public static let openFlickDelay: Double = 0.35

    /// 열려 있는 동안 다음 까딱까지의 간격(초) 범위. 불규칙해야 기계적으로 보이지 않는다.
    public static let idleFlickInterval: ClosedRange<Double> = 7...12

    /// 노치 상단 띠에서 한 픽셀의 크기(pt). 1.5pt는 Retina에서 정확히 3픽셀이라 흐려지지 않는다.
    public static let stripPixelSize: CGFloat = 1.5
}
