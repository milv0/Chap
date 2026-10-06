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
        /// Focus 머리띠(`b`). Focus가 켜져 있는 동안 이마에 묶는다.
        case band
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

    /// 눈 모양. 꼬리 자세와 독립이며 얼굴 칸만 덮어쓴다.
    public enum Eyes: Equatable, Sendable {
        /// 점 두 개(기본 격자).
        case open
        /// 가로 두 칸 선: 잠, 깜빡임.
        case closed
        /// 눈 위에 그림자 눈꺼풀: 졸림.
        case drowsy
    }

    /// 눈 모양별로 격자에 덮어쓸 칸 (x, y, 기호).
    static func eyeCells(_ eyes: Eyes) -> [(x: Int, y: Int, symbol: Character)] {
        switch eyes {
        case .open:
            return []
        case .closed:
            return [(4, 4, "e"), (5, 4, "e"), (7, 4, "e"), (8, 4, "e")]
        case .drowsy:
            return [(4, 3, "s"), (5, 3, "s"), (7, 3, "s"), (8, 3, "s")]
        }
    }

    /// 눈과 꼬리를 합친 격자.
    public static func rows(eyes: Eyes, pose: Pose) -> [String] {
        var grid = (pose == .rest ? rows : tailUpRows).map { Array($0) }
        for cell in eyeCells(eyes) { grid[cell.y][cell.x] = cell.symbol }
        return grid.map { String($0) }
    }

    // MARK: - Focus 머리띠와 돌입 애니메이션

    /// 머리띠가 지나는 이마 칸(2행 x 4…10, 흰 칸만). 왼쪽부터 묶어 나간다.
    public static let headbandCells: [(x: Int, y: Int)] = (4...10).map { (x: $0, y: 2) }

    /// 뒤통수로 나부끼는 머리띠 끈 두 자세. 꼬리를 흔들 때 같이 펄럭인다.
    public static func ribbonCells(_ frame: Int) -> [(x: Int, y: Int)] {
        frame == 1 ? [(12, 2), (13, 1)] : [(12, 2), (13, 2)]
    }

    /// 머리띠 상태. `cells`개까지 이마에 감고, `ribbon`이 0이면 끈 없음, 1·2는 끈 자세.
    public struct Headband: Equatable, Sendable {
        public let cells: Int
        public let ribbon: Int
        public init(cells: Int, ribbon: Int) {
            self.cells = cells
            self.ribbon = ribbon
        }
        /// 다 묶은 머리띠.
        public static func tied(ribbon: Int) -> Headband {
            Headband(cells: ChapMascot.headbandCells.count, ribbon: ribbon)
        }
    }

    /// 눈·꼬리·머리띠를 합친 격자.
    public static func rows(eyes: Eyes, pose: Pose, headband: Headband?) -> [String] {
        var grid = rows(eyes: eyes, pose: pose).map { Array($0) }
        guard let headband else { return grid.map { String($0) } }
        for cell in headbandCells.prefix(max(0, headband.cells)) where grid[cell.y][cell.x] == "w" {
            grid[cell.y][cell.x] = "b"
        }
        if headband.ribbon > 0 {
            for cell in ribbonCells(headband.ribbon) where grid[cell.y][cell.x] == "." {
                grid[cell.y][cell.x] = "b"
            }
        }
        return grid.map { String($0) }
    }

    public static func pixels(eyes: Eyes, pose: Pose, headband: Headband?) -> [Pixel] {
        guard headband != nil else { return pixels(eyes: eyes, pose: pose) }
        return pixels(from: rows(eyes: eyes, pose: pose, headband: headband))
    }

    /// Focus 돌입 한 프레임: 세로 위치(픽셀, 아래가 +), 꼬리, 머리띠, 반짝임.
    public struct FocusEntryStep: Equatable, Sendable {
        public let offsetY: Int
        public let pose: Pose
        public let headband: Headband?
        public let sparkles: Bool
    }

    /// "집중!" 돌입: 웅크리고(아래로 1) → 뛰어오르며 꼬리를 들고(위로 2) → 내려앉아 머리띠를 묶고 →
    /// 끈이 휘날리며 양옆에 반짝임. 끝나면 머리띠를 맨 채 꼬리를 흔든다.
    public static let focusEntrySequence: [FocusEntryStep] = [
        FocusEntryStep(offsetY: 1, pose: .rest, headband: nil, sparkles: false),
        FocusEntryStep(offsetY: 1, pose: .rest, headband: nil, sparkles: false),
        FocusEntryStep(offsetY: -2, pose: .tailUp, headband: nil, sparkles: false),
        FocusEntryStep(offsetY: -2, pose: .tailUp, headband: nil, sparkles: false),
        FocusEntryStep(
            offsetY: 0, pose: .rest, headband: Headband(cells: 3, ribbon: 0), sparkles: false),
        FocusEntryStep(offsetY: 0, pose: .rest, headband: .tied(ribbon: 1), sparkles: true),
        FocusEntryStep(offsetY: 0, pose: .tailUp, headband: .tied(ribbon: 2), sparkles: true),
        FocusEntryStep(offsetY: 0, pose: .rest, headband: .tied(ribbon: 1), sparkles: false),
    ]

    /// 돌입 한 프레임 길이(초). 8프레임 × 0.09 ≈ 0.7초.
    public static let focusEntryFrameDuration: Double = 0.09

    /// 반짝임 픽셀(스프라이트 기준, 바깥으로 나갈 수 있다). 머리 왼쪽 셋, 꼬리 위 둘.
    public static let sparkleCells: [(x: Int, y: Int)] = [
        (-2, 2), (-3, 4), (-2, 6), (25, 1), (26, 3),
    ]

    public static func pixels(eyes: Eyes, pose: Pose) -> [Pixel] {
        eyes == .open ? pixels(for: pose) : pixels(from: rows(eyes: eyes, pose: pose))
    }

    /// 잠든 물범 머리 위로 떠오르는 4×4 z.
    public static let sleepZRows: [String] = [
        "oooo",
        "..o.",
        ".o..",
        "oooo",
    ]

    /// Focus 위젯에서 물범의 상태. Keep Awake가 Mac을 깨워 두는 동안 물범도 깨어 있다.
    public enum FocusMood: Equatable, Sendable {
        /// Focus 꺼짐: 눈 감고 z.
        case asleep
        /// 30분 이상 남음: 눈 뜨고 가끔 깜빡임·꼬리 까딱.
        case awake
        /// 30분 미만(Final stretch, Landing soon): 졸린 눈.
        case drowsy

        public var eyes: Eyes {
            switch self {
            case .asleep: return .closed
            case .awake: return .open
            case .drowsy: return .drowsy
            }
        }
    }

    /// 남은 시간으로 물범 상태를 정한다. 경계는 `KeepAwakePolicy.focusActiveLine`의
    /// Final stretch(30분)와 같다.
    public static func focusMood(remaining: TimeInterval?) -> FocusMood {
        guard let remaining, remaining > 0 else { return .asleep }
        return remaining < 30 * 60 ? .drowsy : .awake
    }

    /// Focus 위젯에서 한 픽셀의 크기(pt). Retina에서 4픽셀.
    public static let widgetPixelSize: CGFloat = 2

    /// Focus가 켜져 있는 동안 꼬리를 쉬지 않고 흔드는 한 프레임의 길이(초).
    /// 졸릴 때는 느려지고, 잠들면 흔들지 않는다(nil).
    public static func focusWagFrameDuration(for mood: FocusMood) -> Double? {
        switch mood {
        case .asleep: return nil
        case .awake: return 0.4
        case .drowsy: return 0.7
        }
    }

    /// 깨어 있을 때 깜빡임 간격(초)과 감은 시간(초).
    public static let blinkInterval: ClosedRange<Double> = 4...7
    public static let blinkDuration: Double = 0.15

    /// z 하나가 떠올라 사라지는 시간(초)과 다음 z까지의 주기(초).
    public static let sleepZRiseDuration: Double = 2.4
    public static let sleepZPeriod: Double = 3

    private static func pixels(from rows: [String]) -> [Pixel] {
        rows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, ch -> Pixel? in
                switch ch {
                case "o", "e": return Pixel(x: x, y: y, ink: .outline)
                case "w": return Pixel(x: x, y: y, ink: .body)
                case "s": return Pixel(x: x, y: y, ink: .shade)
                case "b": return Pixel(x: x, y: y, ink: .band)
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
