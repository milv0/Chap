import CoreGraphics

/// Rectangle(rxhanson/Rectangle)에서 검증된 AX 리사이즈 정책의 순수 코어.
///
/// AX 호출 없이 판정 로직만 담아 테스트로 고정한다. 실제 적용은
/// `LauncherUtils.axApplyBounds`가 이 정책을 따른다.
enum AXResizePolicy {
    /// bounds 적용 단계.
    enum ApplyStep: Equatable {
        case position
        case size
    }

    /// size → position → size.
    ///
    /// macOS는 size를 "현재" 디스플레이에 맞춰 클램프하므로, 창을 다른
    /// 디스플레이로 옮길 때는 먼저 size를 줄이고 → position으로 옮긴 뒤 →
    /// 목표 디스플레이 기준으로 size를 다시 적용해야 한다 (Rectangle과 동일).
    static let applyOrder: [ApplyStep] = [.size, .position, .size]

    /// AX 호출이 응답 없는 앱에서 블로킹되는 시간 상한 (시스템 기본은 수 초).
    static let messagingTimeoutSeconds: Float = 2.0

    /// 앱이 size를 클램프했을 때 요청했던 중앙점을 유지하는 origin.
    ///
    /// 요청 bounds의 중앙 = 실제 bounds의 중앙이 되도록 origin을 절반씩 이동한다.
    /// 좌표계에 무관한 순수 계산이다 (AX top-left 좌표에서 사용).
    static func centerPreservingOrigin(
        requestedOrigin: CGPoint, requestedSize: CGSize, actualSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: requestedOrigin.x + (requestedSize.width - actualSize.width) / 2,
            y: requestedOrigin.y + (requestedSize.height - actualSize.height) / 2)
    }

    /// 실제 size가 tolerance를 넘게 어긋났을 때만 재중앙 보정이 필요하다.
    /// 읽기 실패(nil)는 보정 대상이 아니다.
    static func needsCenterPreservingAdjustment(
        requestedSize: CGSize, actualSize: CGSize?, tolerance: CGFloat
    ) -> Bool {
        guard let actualSize else { return false }
        return abs(actualSize.width - requestedSize.width) > tolerance
            || abs(actualSize.height - requestedSize.height) > tolerance
    }

    /// 요청 size가 창의 최소 size보다 작아 클램프될 것으로 예측되는지.
    /// 진단 로그에서 partial 판정의 원인을 구분하는 데 쓴다.
    static func predictsMinimumSizeClamp(requestedSize: CGSize, minimumSize: CGSize?) -> Bool {
        guard let minimumSize else { return false }
        return requestedSize.width < minimumSize.width
            || requestedSize.height < minimumSize.height
    }

    /// AXEnhancedUserInterface는 원래 켜져 있던 경우에만 복원한다 (Rectangle과 동일).
    static func shouldRestoreEnhancedUI(originalValue: Bool?) -> Bool {
        originalValue == true
    }
}
