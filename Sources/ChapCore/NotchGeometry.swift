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
    /// 배지 왼쪽 아래 볼록 모서리 반경. 상단은 도커와 같은
    /// 오목 플레어(`dockFlareRadius`)를 써서 상단바에서 흘러나오게 한다.
    public static let badgeCornerRadius: CGFloat = 8

    // MARK: 도커 실루엣

    /// 상단 오목 플레어 반경. 도커가 상단바에서 흘러나오는 곡선.
    /// 실루엣과 폭 보정 계산이 함께 쓰므로 반드시 이 값을 공유해야 한다.
    public static let dockFlareRadius: CGFloat = 10
    /// Drop 도커(드롭 존·파일 리스트)의 하단 볼록 모서리 반경.
    public static let dropDockBottomRadius: CGFloat = 18
    /// 메인 런처 패널의 하단 볼록 모서리 반경.
    public static let panelBottomRadius: CGFloat = 20

    // MARK: Drop 존

    /// 드롭 존 콘텐츠 높이. 드롭만 받는 표면이라 낮게 유지한다.
    public static let dropZoneContentHeight: CGFloat = 64

    // MARK: Iceberg 스타일

    /// 빙하 톱니 최대 깊이.
    public static let icebergJagDepth: CGFloat = 46
    /// 빙하 톱니 하나의 목표 폭. 폭에 맞춰 톱니 개수가 정해진다.
    public static let icebergToothWidth: CGFloat = 68

    // MARK: 공통

    /// 그림자가 창 경계에서 잘리지 않도록 형태 주변에 두는 투명 여백.
    /// 그림자 확산이 이 안에서 완전히 소멸해야 경계선이 생기지 않는다.
    public static let shadowPadding: CGFloat = 28
}
