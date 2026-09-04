import CoreGraphics
import Foundation

/// 요청한 창 크기가 대상 앱의 최소 크기보다 작아 클램프됐을 때의 사용자 안내 정책 (순수 로직).
///
/// FLOW.md 이슈 2: 앱이 자체 최소 크기로 클램프하면 `partial`이 되는데, 사용자에게는
/// "크기가 적용 안 됨"으로만 보였다. 원인을 아는 쪽(AX 진단)이 안내까지 담당한다.
enum MinimumSizeNoticePolicy {
    /// 안내 표시 여부.
    /// 앱이 클램프 원인이 되는 최소 크기를 보고했고, 실제 size가 요청대로 적용되지
    /// 않았을 때만 true. 클램프가 예측됐어도 결과가 요청 크기면 안내하지 않는다.
    static func shouldNotify(sizeApplied: Bool, clampingMinimumSize: CGSize?) -> Bool {
        guard clampingMinimumSize != nil else { return false }
        return !sizeApplied
    }

    /// 같은 launchable·요청 크기 조합은 앱 세션당 한 번만 안내하기 위한 키.
    /// 사용자가 설정 크기를 바꾸면 키가 달라져 다시 안내된다.
    static func dedupeKey(siteName: String, requestedSize: CGSize) -> String {
        "\(siteName)|\(Int(requestedSize.width))x\(Int(requestedSize.height))"
    }

    /// 알림 제목.
    static func message(siteName: String) -> String {
        "\"\(siteName)\" couldn't use the configured window size."
    }

    /// 알림 본문: 앱 최소 크기와 현재 설정 크기를 함께 안내한다.
    static func info(minimumSize: CGSize, requestedSize: CGSize) -> String {
        let minimum = "\(Int(minimumSize.width))×\(Int(minimumSize.height))"
        let requested = "\(Int(requestedSize.width))×\(Int(requestedSize.height))"
        return
            "The app enforces a minimum window size of \(minimum), "
            + "but \(requested) is configured. "
            + "Increase the size in Settings to at least the minimum."
    }
}
