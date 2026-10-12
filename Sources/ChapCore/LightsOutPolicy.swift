import Foundation

/// Lights Out(자리 비울 때 화면을 검정으로 덮는 가림막)의 해제 규칙.
///
/// 잠금이 아니다. 비밀번호를 묻지 않고, Chap이 끝나면 걷힌다. 어깨너머 시선을 가리는 용도이며
/// 진짜 보안은 macOS 화면 잠금이 맡는다. 그래서 "잠금·암호" 같은 말을 쓰지 않는다.
public enum LightsOutPolicy {
    /// 해제 키를 Esc로 둘 때 저장하는 값. 글자 키를 고르면 그 한 글자(대문자)를 저장한다.
    public static let escapeKey = "esc"

    /// 입력을 저장할 값으로. 빈 값이거나 "esc"면 Esc, 아니면 첫 글자를 대문자로.
    /// Esc는 늘 쓸 수 있어야 하므로 "해제 키 없음" 상태는 두지 않는다.
    public static func normalized(_ raw: String?) -> String {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
            let first = trimmed.first, trimmed.lowercased() != escapeKey
        else { return escapeKey }
        return String(first).uppercased()
    }

    /// 설정창에 보여 줄 키 이름.
    public static func label(for key: String) -> String {
        normalized(key) == escapeKey ? "Esc" : normalized(key)
    }

    /// 설정창 입력 칸을 고친 결과. 칸에는 "Esc"(세 글자)나 한 글자가 보이므로,
    /// 글자가 줄었으면(지움) Esc로 돌아가고, 늘었으면 마지막에 친 글자를 키로 쓴다.
    /// "Esc"에서 한 글자를 지웠을 때 "S"가 키가 되는 일을 막는다.
    public static func keyAfterEditing(currentKey: String, newText: String) -> String {
        guard newText.count > label(for: currentKey).count, let last = newText.last else {
            return escapeKey
        }
        return normalized(String(last))
    }

    /// 누른 키가 가림막을 걷는 키인지.
    /// - Parameters:
    ///   - isEscape: Esc(keyCode 53)인지.
    ///   - characters: 수식키를 뺀 입력 글자.
    ///   - unlockKey: 설정에 저장된 해제 키.
    public static func unlocks(isEscape: Bool, characters: String?, unlockKey: String) -> Bool {
        let key = normalized(unlockKey)
        if key == escapeKey { return isEscape }
        return characters?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == key
    }

    // MARK: - 해제 키를 잊었을 때

    /// 아무 키나 이 횟수만큼 빠르게 누르면 걷힌다. 외울 것이 없고, 지나가다 눌리지도 않는다.
    public static let rapidPressCount = 5
    /// 그 횟수를 채워야 하는 시간(초).
    public static let rapidPressWindow: TimeInterval = 2

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

    // MARK: - 화면 문구

    /// 가림막 아래쪽에 잠깐 떴다 사라지는 안내.
    public static func hint(unlockKey: String) -> String {
        "Press \(label(for: unlockKey)) to come back"
    }

    /// 안내가 보이는 시간(초). 이후에는 검정과 자는 물범, 시간만 남는다.
    public static let hintDuration: TimeInterval = 4

    /// 메뉴 항목 문구. 켜고 끄는 말을 Focus의 on/off와 같은 결로 맞춘다.
    public static let menuTitleOff = "Lights Out"
    public static let menuTitleOn = "Lights On"
    /// 설정·메뉴의 보조 한 줄.
    public static let subtitle = "Keeps your screens dark while you're on break."
}
