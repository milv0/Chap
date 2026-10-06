import CoreGraphics

/// 접힌 위젯 칸이 아이콘으로 올라가는 "어깨" 영역 규칙.
///
/// 어깨는 검정 띠가 노치 plateau 바깥에서 곡선(`stripFalloff`)으로 얇아진 뒤 도커 양 끝까지
/// 남는 메뉴 막대 높이의 밝은 띠다. 칸을 접어도 도커 폭은 그대로 두고(칸이 펼쳐져 있을 때의 폭),
/// 접힌 칸은 원래 자리가 노치 왼쪽이면 왼쪽 어깨, 오른쪽이면 오른쪽 어깨에 아이콘으로 놓인다.
public enum NotchShoulderPolicy {
    /// 접을 수 있는 위젯. 파일을 보여주는 선반만 접는다.
    public static let collapsibleWidgets: Set<NotchWidget> = [.screenshots, .downloads]

    /// 어깨 아이콘 간격(누름 폭). 띠 도구와 같다.
    public static let iconPitch: CGFloat = 28
    /// 도커 바깥 모서리(오목 플레어 안쪽)와 첫 아이콘 사이 여백.
    public static let outerMargin: CGFloat = 8
    /// 어깨 아이콘 글리프 크기(pt).
    public static let iconSize: CGFloat = 16
    /// 띠 가운데보다 아래로 내리는 광학 보정. 아이콘이 위 화면 경계에 붙어 보이지 않게 한다.
    public static let iconDrop: CGFloat = 3

    public enum Side: Equatable, Sendable {
        case left
        case right
    }

    /// 저장값 정리: 접을 수 있는 위젯만, 중복 없이, 처음 순서대로.
    public static func normalized(_ raw: [NotchWidget]) -> [NotchWidget] {
        var seen = Set<NotchWidget>()
        return raw.filter { collapsibleWidgets.contains($0) && seen.insert($0).inserted }
    }

    /// 칸 폭들로 이루어진 가운데 정렬 줄에서 각 칸이 노치 왼쪽인지 오른쪽인지.
    /// 줄의 가운데가 도커 가운데(= 노치 가운데)다. 정확히 가운데인 칸은 왼쪽으로 친다.
    public static func sides(widths: [CGFloat], spacing: CGFloat) -> [Side] {
        guard !widths.isEmpty else { return [] }
        let rowWidth = widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
        var x: CGFloat = 0
        return widths.map { width in
            let center = x + width / 2
            x += width + spacing
            return center <= rowWidth / 2 ? .left : .right
        }
    }

    /// 펼친 칸 기준 줄 폭. 칸을 접어도 도커는 이 폭을 유지한다.
    public static func rowWidth(widths: [CGFloat], spacing: CGFloat) -> CGFloat {
        guard !widths.isEmpty else { return 0 }
        return widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
    }

    /// 한쪽 어깨에 아이콘 `count`개를 놓을 수 있는 최소 도커 폭.
    /// 도커 반폭 = plateau 반폭 + 곡선 감쇠 + 플레어 + 여백 + 아이콘들.
    public static func minimumDockWidth(iconsPerSide count: Int, plateauHalfWidth: CGFloat)
        -> CGFloat
    {
        guard count > 0 else { return 0 }
        let half =
            plateauHalfWidth + NotchGeometry.stripFalloff + NotchGeometry.dockFlareRadius
            + outerMargin + CGFloat(count) * iconPitch
        return 2 * half
    }

    /// 어깨 아이콘 중심의 x (도커 왼쪽 끝 기준). 바깥 모서리부터 칸 순서대로 놓는다:
    /// 왼쪽은 왼쪽 끝에서 오른쪽으로, 오른쪽은 오른쪽 끝에서 왼쪽으로.
    /// `index`는 그 어깨 안에서 바깥부터 센 순번이다.
    public static func iconCenterX(side: Side, index: Int, dockWidth: CGFloat) -> CGFloat {
        let fromEdge =
            NotchGeometry.dockFlareRadius + outerMargin + iconPitch / 2
            + CGFloat(index) * iconPitch
        return side == .left ? fromEdge : dockWidth - fromEdge
    }

    /// 어깨 아이콘 중심의 y. 띠 가장자리 깊이와 노치 높이 사이 가운데에서 `iconDrop`만큼 아래.
    public static func iconCenterY(topInset: CGFloat, edgeDepth: CGFloat) -> CGFloat {
        (topInset + edgeDepth) / 2 + iconDrop
    }
}
