import CoreGraphics

/// 노치 표면(패널·Drop 도커·배지)의 모든 조정 가능한 수치의 단일 출처.
///
/// 시각 스펙을 조율할 때는 이 파일과 `NOTCH.md`의 다이어그램만 보면 된다.
/// 런타임 파생 값(노치 폭/높이)은 화면 API에서 계산하므로 여기 없다:
/// 노치 폭 = auxiliary area 간격, 노치 높이 = safe area top inset,
/// 배지 한 변 = 노치 높이, 도커 span = 노치 폭 + 배지 한 변 × 2 + 플레어 × 2.
public enum NotchGeometry {
    // MARK: Drop 배지

    /// 배지가 노치 안쪽으로 파고드는 겹침. 노치의 둥근 오른쪽 아래 모서리를
    /// 검정으로 채워 노치가 오른쪽으로 길어져 보이게 한다.
    public static let badgeNotchOverlap: CGFloat = 12
    /// 배지 본체(보이는 검정)의 폭. 높이는 노치 높이(32)를 따르므로
    /// 34×32의 살짝 가로로 긴 비율이 된다.
    public static let badgeBodyWidth: CGFloat = 34
    /// 배지 하단 바깥 볼록 모서리 반경. 실제 노치의 라운드보다 크면 이질감이
    /// 생기므로 하드웨어 곡률에 가깝게 작게 유지한다. 상단은 도커와 같은
    /// 오목 플레어(`dockFlareRadius`)를 써서 상단바에서 흘러나오게 한다.
    public static let badgeCornerRadius: CGFloat = 6

    // MARK: 도커 실루엣

    /// 상단 오목 플레어 반경. 도커가 상단바에서 흘러나오는 곡선.
    /// 실루엣과 폭 보정 계산이 함께 쓰므로 반드시 이 값을 공유해야 한다.
    public static let dockFlareRadius: CGFloat = 10
    /// 모든 도커(메인 패널·드롭 존·Drop 리스트)의 하단 볼록 모서리 반경.
    /// 배지만 본체가 작아 비례상 더 작은 `badgeCornerRadius`를 쓴다.
    public static let dockBottomRadius: CGFloat = 18

    // MARK: Drop 존

    /// 드롭 존 콘텐츠 높이. 드롭만 받는 표면이라 낮게 유지한다.
    public static let dropZoneContentHeight: CGFloat = 64

    // MARK: Iceberg 스타일

    /// 빙하 톱니 최대 깊이.
    public static let icebergJagDepth: CGFloat = 46
    /// 빙하 톱니 하나의 목표 폭. 폭에 맞춰 톱니 개수가 정해진다.
    public static let icebergToothWidth: CGFloat = 68

    // MARK: 공통

    /// 그림자가 창 경계에서 잘리지 않도록 형태 주변에 두는 투명 여ㄹ백.
    /// 그림자 확산이 이 안에서 완전히 소멸해야 경계선이 생기지 않는다.
    public static let shadowPadding: CGFloat = 28

    /// 도커를 여는 hover/드래그 인식 범위를 시각 경계보다 넓히는 여유.
    /// 노치·배지 가장자리를 정확히 맞추지 않아도 반응하게 한다.
    public static let hoverMargin: CGFloat = 10

    // MARK: 눌린 상단 띠 (pressed strip)

    /// 도커 좌우 끝에서 검정 띠가 남는 최소 깊이.
    public static let stripEdgeDepth: CGFloat = 6
    /// 노치 plateau 바깥에서 검정이 가장자리 깊이로 얇아지는 감쇠 길이.
    /// 검정의 최대 깊이는 항상 노치 세로(topInset)와 같다.
    public static let stripFalloff: CGFloat = 90
}
