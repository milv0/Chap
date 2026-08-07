import Foundation

/// 앱 재실행 및 제거 과정에서 부작용을 내기 전에 결정할 수 있는 순수·파일 시스템 헬퍼.
enum AppLifecycleSupport {
    /// `/bin/sh -c`에서 앱 경로를 코드 문자열에 보간하지 않고 위치 매개변수 `$1`로 전달한다.
    ///
    /// `chap-restart`는 `$0` 자리표시자이므로 `appPath`는 언제나 `$1`에만 들어간다.
    static func restartTaskArguments(appPath: String) -> [String] {
        ["-c", "sleep 1; open -- \"$1\"", "chap-restart", appPath]
    }

    /// 메인 설정과 백업 파일을 제거한다. 존재하지 않는 파일은 정상 상태로 간주한다.
    static func removeConfigurationFiles(
        configPath: String,
        fileManager: FileManager = .default
    ) throws {
        for path in [configPath, configPath + ".bak"] where fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }
}
