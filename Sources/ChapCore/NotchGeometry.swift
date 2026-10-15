import CoreGraphics

/// 노치 표면(패널·Drop 도커·배지)의 모든 조정 가능한 수치의 단일 출처.
///
/// 시각 스펙을 조율할 때는 이 파일과 `NOTCH.md`의 다이어그램만 보면 된다.
/// 런타임 파생 값(노치 폭/높이)은 화면 API에서 계산하므로 여기 없다:
/// 노치 폭 = auxiliary area 간격, 노치 높이 = safe area top inset,
/// 배지 한 변 = 노치 높이, 도커 span = 노치 폭 + 배지 한 변 × 2 + 플레어 × 2.
public enum NotchGeometry {
    // MARK: Drop 배지

    /// 배지가 노치 안쪽으로 파고드는 겹침. 노치의 둥근 아래 모서리를 검정으로 채워
    /// 노치가 옆으로 길어져 보이게 한다. 노치 모서리는 연속 곡률이라 반경(약 13pt)보다
    /// 안쪽(약 17pt)까지 휘므로, 그보다 깊게 파고들어야 이음새에 홈이 남지 않는다.
    /// 겹친 부분은 하드웨어 노치 밑이라 보이지 않는다.
    public static let badgeNotchOverlap: CGFloat = 18
    /// 배지 본체(보이는 검정)의 폭. 높이는 노치 높이(32)를 따르므로
    /// 34×32의 살짝 가로로 긴 비율이 된다.
    public static let badgeBodyWidth: CGFloat = 34
    /// 노치 왼쪽 타이머 배지 본체 폭. "1:02:05"(12pt)가 들어가는 폭이다.
    public static let timerBadgeBodyWidth: CGFloat = 52
    /// 노치 좌우에 확보하는 평평한 검정 plateau 영역 폭.
    /// 왼쪽은 Keep Awake 상태, 오른쪽은 Drop 배지와 향후 상태 표시에 쓴다.
    public static let stripPlateauSideWidth: CGFloat = 110
    /// 배지 하단 바깥 볼록 모서리 반경. 하드웨어 노치의 아래 모서리와 같은 크기로 맞추고
    /// `.continuous`(스퀴클)로 그려, 노치 옆에 붙어도 곡률이 따로 놀지 않는다.
    /// 애플이 수치를 공개하지 않아 실측에 가까운 값이다(노치 높이 32~38pt 기준 약 13pt).
    public static let badgeCornerRadius: CGFloat = 13
    /// 배지 상단 바깥 오목 플레어 반경. 하드웨어 노치가 메뉴 막대와 만나는 곡선(약 6pt)에 맞춘다.
    /// 도커의 플레어(`dockFlareRadius` 10)보다 작다: 배지는 노치와 나란히 보이는 작은 표면이다.
    public static let badgeFlareRadius: CGFloat = 6

    // MARK: 도커 실루엣

    /// 상단 오목 플레어 반경. 도커가 상단바에서 흘러나오는 곡선.
    /// 실루엣과 폭 보정 계산이 함께 쓰므로 반드시 이 값을 공유해야 한다.
    public static let dockFlareRadius: CGFloat = 10
    /// 모든 도커(메인 패널·드롭 존·Drop 리스트)의 하단 볼록 모서리 반경.
    /// 배지만 본체가 작아 비례상 더 작은 `badgeCornerRadius`를 쓴다.
    public static let dockBottomRadius: CGFloat = 18
    /// Liquid Glass의 자체 광학 edge inset을 외곽으로 밀어내는 bleed.
    /// 유리가 오목 플레어 안쪽에서 끊기지 않고 검정 꼭짓점까지 이어지게 한다.
    public static let glassEdgeBleed: CGFloat = 10

    // MARK: 공통

    /// 그림자가 창 경계에서 잘리지 않도록 형태 주변에 두는 투명 여백.
    /// 그림자 확산이 이 안에서 완전히 소멸해야 경계선이 생기지 않는다.
    public static let shadowPadding: CGFloat = 28

    /// 노치 하단 경계와 도커 콘텐츠(섹션 헤더) 사이 세로 간격.
    public static let contentTopGap: CGFloat = 15

    /// 도커를 여는 hover/드래그 인식 범위를 시각 경계보다 넓히는 여유.
    /// 노치·배지 가장자리를 정확히 맞추지 않아도 반응하게 한다.
    public static let hoverMargin: CGFloat = 0

    // MARK: 눌린 상단 띠 (pressed strip)

    /// 도커 좌우 끝에서 검정 띠가 남는 최소 깊이.
    public static let stripEdgeDepth: CGFloat = 6
    /// 노치 plateau 바깥에서 검정이 가장자리 깊이로 얇아지는 감쇠 길이.
    /// 검정의 최대 깊이는 항상 노치 세로(topInset)와 같다.
    public static let stripFalloff: CGFloat = 90
}
