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
        /// Focus 물속(깊은 블루). 몸 아래쪽을 덮어 물에 잠긴 모습이 된다.
        case water
        /// 물결 마루(밝은 블루).
        case crest
        /// 다이빙 물방울.
        case splash
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

    // MARK: - Focus 다이빙(몰입)

    /// 수면 높이(스프라이트 행). 다이빙하는 동안만 이 아래가 물이다.
    public static let waterLevel = 9
    /// 물이 깔리는 가로 범위(스프라이트 기준, 몸보다 조금 넓다)와 물속 바닥 행.
    public static let waterSpan = -3...26
    public static let waterBottom = 13

    /// 열 `x`의 수면(마루) 행. 네 칸마다 두 칸씩 한 칸 낮고, `phase`만큼 흘러간다.
    public static func surfaceRow(x: Int, level: Int, phase: Int) -> Int {
        level + (((x + phase) % 4 + 4) % 4 < 2 ? 0 : 1)
    }

    /// 물 픽셀: 마루 한 줄 + 그 아래 `rows`줄(nil이면 바닥까지). `rows` 0이면 얇은 수면 한 줄만.
    public static func waterPixels(level: Int, phase: Int, rows: Int? = nil) -> [Pixel] {
        waterSpan.flatMap { x -> [Pixel] in
            let top = surfaceRow(x: x, level: level, phase: phase)
            let bottom = rows.map { top + $0 } ?? waterBottom
            let body =
                bottom > top ? ((top + 1)...bottom).map { Pixel(x: x, y: $0, ink: .water) } : []
            return [Pixel(x: x, y: top, ink: .crest)] + body
        }
    }

    /// 다이빙·떠오르기 한 프레임: 물범 세로 위치(픽셀, 아래가 +), 꼬리, 수면(nil이면 물 없음),
    /// 물결 위상, 수면 아래 물 줄 수(nil이면 바닥까지, 0이면 수면 한 줄), 물방울.
    /// 물범은 수면 아래로 내려간 부분이 그려지지 않는다.
    public struct FocusDiveStep: Equatable, Sendable {
        public let offsetY: Int
        public let pose: Pose
        public let waterLevel: Int?
        public let wavePhase: Int
        public let waterRows: Int?
        public let splash: [Pixel]

        init(
            _ offsetY: Int, _ pose: Pose = .rest, water: Int? = nil, phase: Int = 0,
            rows: Int? = nil, splash: [(Int, Int)] = []
        ) {
            self.offsetY = offsetY
            self.pose = pose
            self.waterLevel = water
            self.wavePhase = phase
            self.waterRows = rows
            self.splash = splash.map { Pixel(x: $0.0, y: $0.1, ink: .splash) }
        }
    }

    /// "몰입" 다이빙: 웅크림 → 꼬리를 들고 뛰어오름 → 첨벙 뛰어들어 잠깐 잠김 → 튀어 올라 첨벙 → 물이 빠지고 엎드림.
    /// 켜는 순간의 연출로만 쓰고, 끝나면 물 없이 원래 자리에서 꼬리를 흔든다(잠수·헤엄은 뺐다).
    public static let focusDiveSequence: [FocusDiveStep] = [
        FocusDiveStep(1),
        FocusDiveStep(-3, .tailUp),
        FocusDiveStep(-3, .tailUp),
        FocusDiveStep(0, .tailUp, water: waterLevel + 2, splash: [(-1, 8), (24, 8)]),
        FocusDiveStep(
            3, water: waterLevel, phase: 1, splash: [(-2, 5), (-1, 7), (24, 6), (25, 4)]),
        FocusDiveStep(5, water: waterLevel, phase: 2, splash: [(-3, 3), (26, 2), (25, 5)]),
        FocusDiveStep(2, water: waterLevel, phase: 3, splash: [(-3, 6), (26, 6)]),
        FocusDiveStep(
            -1, .tailUp, water: waterLevel + 1, splash: [(-2, 5), (25, 5), (-1, 3), (24, 3)]),
        FocusDiveStep(0, water: waterLevel + 2, splash: [(-2, 8), (25, 8)]),
        FocusDiveStep(0),
    ]

    /// 다이빙 한 프레임 길이(초). 10프레임 × 0.1 = 1초.
    public static let focusDiveFrameDuration: Double = 0.1

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
