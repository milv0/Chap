import Foundation

/// Cover Screens(자리 비울 때 화면을 검정으로 덮는 가림막)의 켜고 걷는 규칙.
///
/// 잠금이 아니다. 비밀번호를 묻지 않고, Chap이 끝나면 걷힌다. 어깨너머 시선을 가리는 용도이며
/// 진짜 보안은 macOS 화면 잠금이 맡는다. 그래서 "잠금·암호" 같은 말을 쓰지 않는다.
public enum CoverScreensPolicy {
    // MARK: - 걷는 법: ⌥ 한 번

    /// ⌥(Option)만 눌렀다 떼면 걷힌다. 켤 때 ⌥L을 썼으니 손이 이미 ⌥ 위에 있다.
    ///
    /// "누름 → 다른 키 없이 뗌"을 한 번의 탭으로 본다:
    /// - 가림막이 뜬 순간 이미 ⌥가 눌려 있으면(⌥L을 아직 떼지 않음) 그 뗌은 세지 않는다.
    /// - ⌥를 누른 채 다른 키를 치면(⌥L 등) 그 탭은 취소된다. 걷자마자 ⌥L이 다시 덮는 일을 막는다.
    public struct OptionTap: Equatable, Sendable {
        /// 가림막이 뜬 뒤에 ⌥가 눌렸고, 그 사이 다른 키가 없었는지.
        private var armed = false
        private var isDown: Bool

        /// - Parameter optionHeldAtStart: 가림막이 뜬 순간 ⌥가 눌려 있었는지.
        public init(optionHeldAtStart: Bool) {
            isDown = optionHeldAtStart
        }

        /// 수식키 상태가 바뀔 때. ⌥ 탭이 끝났으면(뗌) true.
        /// - Parameters:
        ///   - optionDown: 지금 ⌥가 눌려 있는지.
        ///   - otherModifiersDown: ⌘·⌃·⇧ 같은 다른 수식키가 같이 눌려 있는지. ⌘⌥처럼 함께 누르면 탭이 아니다.
        public mutating func modifiersChanged(optionDown: Bool, otherModifiersDown: Bool) -> Bool {
            defer { isDown = optionDown }
            if otherModifiersDown { armed = false }
            if optionDown, !isDown { armed = !otherModifiersDown }
            guard !optionDown, isDown, armed else { return false }
            armed = false
            return true
        }

        /// ⌥를 누른 채 다른 키를 쳤을 때. 그 탭은 걷는 동작이 아니다.
        public mutating func otherKeyPressed() { armed = false }
    }

    // MARK: - 켜는 단축키

    /// 가림막을 치는 ⌥ 키. 기본 ⌥L. 사이트 단축키와 Quick Note 키가 먼저다.
    public static let defaultShortcut = "L"

    /// 실제로 등록할 키. 키가 있고, 예약키·사이트·Quick Note와 겹치지 않을 때만.
    /// 노치와 무관하다(메뉴바 기능이라 노치가 없거나 꺼져 있어도 쓴다).
    public static func registeredShortcut(
        _ shortcut: String?, sites: [Site], quickNoteKey: String?
    ) -> String? {
        guard let key = QuickNoteShortcutPolicy.normalized(shortcut),
            conflict(for: key, sites: sites, quickNoteKey: quickNoteKey) == nil
        else { return nil }
        return key
    }

    public static func conflict(for key: String?, sites: [Site], quickNoteKey: String?)
        -> QuickNoteShortcutPolicy.Conflict?
    {
        QuickNoteShortcutPolicy.conflict(
            for: key, sites: sites,
            taken: quickNoteKey.map { [(key: $0, name: "Quick Note")] } ?? [])
    }

    // MARK: - ⌥를 잊었을 때

    /// 아무 키나 이 횟수만큼 빠르게 누르면 걷힌다. 외울 것이 없고, 실수로 채우기는 어렵다.
    public static let rapidPressCount = 10
    /// 그 횟수를 채워야 하는 시간(초). 10번을 1초에 4번 남짓 치면 닿는다.
    public static let rapidPressWindow: TimeInterval = 3

    /// 비상 해제 연타로 셀 입력인지. 키를 누르고 있을 때 생기는 자동 반복은 세지 않는다.
    /// 세면 키보드 위에 무언가 놓이거나 키를 0.5초만 눌러도 가림막이 걷힌다.
    public static func countsAsPress(isRepeat: Bool) -> Bool { !isRepeat }

    /// 최근 키 입력 시각들로 비상 해제 여부를 본다. 창 밖으로 밀려난 입력은 세지 않는다.
    public static func isRapidEscape(presses: [Date], now: Date = Date()) -> Bool {
        recentPresses(presses, now: now).count >= rapidPressCount
    }

    /// 시간 창 안에 남는 입력만 추린다(가장 오래된 것부터). 창을 벗어난 입력은 버린다.
    public static func recentPresses(_ presses: [Date], now: Date = Date()) -> [Date] {
        presses.filter { now.timeIntervalSince($0) < rapidPressWindow && $0 <= now }
            .sorted()
            .suffix(rapidPressCount)
            .map { $0 }
    }

    // MARK: - 화면 나누기

    /// 시계·물범 낮잠·문구·안내를 그릴 화면. 내장 화면(노치가 있는 MacBook 화면)이 있으면 그 화면,
    /// 없으면(덮개를 닫은 채 외장 모니터만 쓸 때 등) 첫 화면(메뉴 막대가 있는 화면).
    /// 나머지 화면에서는 물범이 헤엄친다.
    public static func clockScreenIndex(builtIn: [Bool]) -> Int {
        builtIn.firstIndex(of: true) ?? 0
    }

    /// 보조 화면 물범과 물의 밝기. 낮잠 물범과 같은 결로 어둡게 둔다.
    public static let swimSealOpacity: Double = 0.6
    public static let swimWaterOpacity: Double = 0.45
    /// 보조 화면 수면 높이(화면 높이에 대한 비율, 위에서부터).
    public static let swimWaterlineFraction: Double = 0.62

    // MARK: - 화면 문구

    /// 가림막 아래쪽에 잠깐 떴다 사라지는 안내.
    public static let hint = "Tap ⌥ Option to come back"

    // MARK: - 사용자 문구

    /// 가림막 시계 아래에 계속 보이는 문구(예: "Back in 10 minutes"). 한 줄, 이 길이까지.
    public static let messageMaxLength = 80

    /// 저장할 문구: 줄바꿈을 공백으로, 앞뒤 공백을 지우고, 상한 길이로 자른다. 비면 nil(문구 없음).
    public static func cleanedMessage(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let oneLine = raw.components(separatedBy: .newlines).joined(separator: " ")
        let trimmed = oneLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > messageMaxLength ? String(trimmed.prefix(messageMaxLength)) : trimmed
    }

    /// 가림막 위 물범·시간·안내의 밝기(불투명도). 검정 위에서 또렷이 읽히되 눈부시지 않게 둔다.
    /// 처음 값(0.22·0.26·0.3)은 너무 흐려 알아보기 어려웠다.
    public static let sealOpacity: Double = 0.6
    /// 자는 물범이 숨 쉬듯 밝아졌다 어두워지는 범위와 한 번의 들숨(초). 픽셀 그림이 흐려지지 않도록
    /// 크기나 위치 대신 밝기만 바꾼다. 동작 줄이기가 켜져 있으면 `sealOpacity`에 머문다.
    public static let sealBreathOpacity: ClosedRange<Double> = 0.5...0.72
    public static let sealBreathDuration: Double = 2.2
    public static let clockOpacity: Double = 0.65
    public static let hintOpacity: Double = 0.55

    /// 안내가 보이는 시간(초). 이후에는 검정과 자는 물범, 시간만 남는다.
    public static let hintDuration: TimeInterval = 4

    /// 메뉴 항목 문구. 켜고 끄는 말을 Focus의 on/off와 같은 결로 맞춘다.
    public static let menuTitleOff = "Cover Screens"
    public static let menuTitleOn = "Uncover Screens"
    /// 설정·메뉴의 보조 한 줄.
    public static let subtitle = "Keeps your screens dark while you're on break."
}
