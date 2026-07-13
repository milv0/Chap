import Foundation
import os

/// 통합 로깅(os.Logger) 진입점.
///
/// Console.app / `log` CLI에서 subsystem·category·레벨로 필터링할 수 있다.
/// 예: `log stream --predicate 'subsystem == "com.mingyupark.Chap"'`
///
/// 레벨 가이드:
/// - `.debug`  개발 중에만 관심 있는 상세 흐름 (릴리스에선 기본적으로 저장 안 됨)
/// - `.info`   정상 동작의 주요 이벤트
/// - `.error`  복구 가능한 오류 (권한 없음, 실행 실패 등)
/// - `.fault`  프로그래밍 오류/치명적 상태
///
/// 사용자 데이터(사이트 이름, 경로, URL 등)는 기본적으로 `privacy: .private`로
/// 마스킹해 통합 로그에 평문으로 남지 않게 한다.
public enum Log {
    private static let subsystem =
        Bundle.main.bundleIdentifier ?? "com.mingyupark.Chap"

    /// 앱 생명주기, 이벤트 탭, 권한 등 전반
    public static let app = Logger(subsystem: subsystem, category: "app")
    /// 사이트 실행 및 윈도우 리사이즈 (Chrome/App/Finder/Shell)
    public static let launcher = Logger(subsystem: subsystem, category: "launcher")
    /// 설정 로드/저장/마이그레이션/가져오기·내보내기
    public static let config = Logger(subsystem: subsystem, category: "config")
}
