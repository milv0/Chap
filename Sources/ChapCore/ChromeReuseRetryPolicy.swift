import Foundation

/// Chrome 창 재사용 AppleScript가 일시적으로 실패했을 때의 재시도 정책 (순수 로직).
///
/// 재사용 스크립트가 한 번 실패하면 즉시 새 창 폴백(수 초짜리 느린 경로)으로 빠져
/// "첫 실행은 실패하고 다시 누르면 된다"로 체감된다. 일시 오류는 짧게 한 번만
/// 재시도해 같은 실행 안에서 회복할 기회를 준다.
enum ChromeReuseRetryPolicy {
    /// 최초 시도를 포함한 최대 시도 횟수.
    static let maxAttempts = 2

    /// 재시도 전 대기 (마이크로초).
    static let retryDelayMicroseconds: UInt32 = 150_000

    /// 재시도 여부 판정.
    /// - Parameters:
    ///   - attempt: 0부터 시작하는 방금 실패한 시도 번호.
    ///   - isPermissionDenied: 자동화 권한 거부 여부. 사용자 조치가 필요한 상태라
    ///     재시도해도 회복되지 않고 권한 안내만 중복될 수 있으므로 재시도하지 않는다.
    static func shouldRetry(attempt: Int, isPermissionDenied: Bool) -> Bool {
        attempt + 1 < maxAttempts && !isPermissionDenied
    }
}
