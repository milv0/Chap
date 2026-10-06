import CoreGraphics

/// 접을 수 있는 선반 칸과, 접어도 도커 폭을 유지하는 규칙.
///
/// 접힌 칸은 검정 띠 왼쪽에 흰 아이콘으로 놓인다(`NotchLauncherPolicy.leftStripIconCenterOffsets`).
/// 검정 곡선 바깥의 밝은 "어깨" 영역은 비워 두며, 렌더·Debug 경계선(`showsShoulderGuides`)으로만 표시한다.
public enum NotchShoulderPolicy {
    /// 접을 수 있는 위젯. 파일을 보여주는 선반만 접는다.
    public static let collapsibleWidgets: Set<NotchWidget> = [.screenshots, .downloads]

    /// 저장값 정리: 접을 수 있는 위젯만, 중복 없이, 처음 순서대로.
    public static func normalized(_ raw: [NotchWidget]) -> [NotchWidget] {
        var seen = Set<NotchWidget>()
        return raw.filter { collapsibleWidgets.contains($0) && seen.insert($0).inserted }
    }

    /// 펼친 칸 기준 줄 폭. 칸을 접어도 도커는 이 폭을 유지한다.
    public static func rowWidth(widths: [CGFloat], spacing: CGFloat) -> CGFloat {
        guard !widths.isEmpty else { return 0 }
        return widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
    }
}
