import CoreGraphics
import Foundation

/// 저장(비편집) 상태의 설정 패널을 탭했을 때 편집 모드를 켤지 판정하는 순수 로직.
///
/// Shell은 스크립트 편집기 내부를 탭했을 때만 편집을 켠다. 스크립트는 여러 줄이라
/// 실수로 패널 여백을 눌러 편집이 켜지는 것이 다른 타입보다 위험하기 때문.
/// 나머지 타입은 기존처럼 패널 어디를 탭해도 편집을 켠다.
enum EditActivationPolicy {
    /// - Parameters:
    ///   - launchType: 선택된 launchable의 타입.
    ///   - tapLocation: 탭 위치 (scriptEditorFrame과 같은 좌표계).
    ///   - scriptEditorFrame: Shell 스크립트 편집기 상자의 프레임. 레이아웃 전이면 .zero.
    static func shouldEnableEditing(
        launchType: LaunchType, tapLocation: CGPoint, scriptEditorFrame: CGRect
    ) -> Bool {
        guard launchType == .shell else { return true }
        return scriptEditorFrame.contains(tapLocation)
    }
}
