import Foundation

/// 카메라 권한 상태. AVFoundation의 AVAuthorizationStatus를 테스트 가능한 값으로 옮긴다.
public enum CameraAccess: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// 노치 거울 위젯이 보여줄 화면.
public enum MirrorDisplayState: Equatable, Sendable {
    /// 아직 묻지 않았다. 사용자가 버튼을 눌러야 권한을 요청한다
    /// (노치에 마우스를 올린 것만으로 권한 창을 띄우지 않는다).
    case needsPermission
    /// 실시간 미리보기.
    case live
    /// 거부됨. 시스템 설정으로 안내한다.
    case denied
    /// 기기 정책으로 막힘. 사용자가 바꿀 수 없다.
    case restricted
    /// 연결된 카메라가 없다.
    case noCamera
}

/// 거울 위젯의 상태·캡처 판정. 카메라 켜짐 표시등이 불필요하게 켜지지 않도록
/// "사용자가 켠 거울이 열린 도커에 있을 때"만 캡처한다.
/// 거울은 도커를 열 때마다 꺼진 상태(아이콘)로 시작한다.
public enum MirrorPolicy {
    public static func displayState(access: CameraAccess, hasCamera: Bool) -> MirrorDisplayState {
        guard hasCamera else { return .noCamera }
        switch access {
        case .notDetermined: return .needsPermission
        case .authorized: return .live
        case .denied: return .denied
        case .restricted: return .restricted
        }
    }

    public static func shouldCapture(
        state: MirrorDisplayState, isTurnedOn: Bool, isPanelOpen: Bool
    ) -> Bool {
        state == .live && isTurnedOn && isPanelOpen
    }
}
