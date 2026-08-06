import Foundation

/// 리사이즈 결과를 CSV 파일로 자동 수집하는 로거 (DEBUG 빌드 전용)
/// 저장 위치: ~/Library/Logs/Chap/resize_YYYY-MM-DD.csv
///
/// 리사이즈 튜닝용 계측 데이터이므로 릴리스 빌드에서는 아무것도 기록하지 않는다.
/// 최종 사용자 기기에 사용 이력(무엇을 언제 열었는지)이 쌓이는 것을 막기 위함.
/// CSV 열: timestamp,site,type,app_state,attempt,delay,total_time,result,window_count,display,
/// size,detail
///
/// `detail`은 마지막 열로 추가됐다. 헤더는 파일 생성 시 한 번만 쓰므로 그 이전에 만들어진
/// 파일에는 헤더에 `detail`이 없다. 1~11열 위치는 그대로여서 기존 분석은 계속 동작한다.
enum ResizeLogger {
    #if DEBUG
        private static let fileLock = NSLock()

        private static let logDir: String = {
            let home = NSHomeDirectory()
            return (home as NSString).appendingPathComponent("Library/Logs/Chap")
        }()

        /// CSV 한 칸에 안전하게 넣기 위해 구분자·줄바꿈을 치환한다.
        /// 사이트 이름·디스플레이 이름·진단 문자열에 콤마가 들어가면 열이 밀리기 때문.
        private static func csvSafe(_ value: String) -> String {
            value
                .replacingOccurrences(of: ",", with: ";")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
        }
    #endif

    /// 리사이즈 결과 기록 (DEBUG 빌드에서만 동작, 릴리스에서는 no-op)
    /// - Parameters:
    ///   - site: 사이트 이름
    ///   - type: 런처 타입 (url, app, finder, shell)
    ///   - appState: 앱 상태 ("running" 또는 "cold")
    ///   - attempt: 성공한 시도 번호 (1-based)
    ///   - delay: 해당 시도의 대기 시간
    ///   - totalTime: 시작부터 성공/실패까지 총 소요 시간
    ///   - result: "success" 또는 "failed"
    ///   - windowCount: 해당 앱의 윈도우 수
    ///   - display: 대상 디스플레이 이름
    ///   - size: 윈도우 크기 "WxH"
    ///   - detail: 판정 근거 (요청 대비 실제 position/size, AX 에러 코드, 창 상태 요약)
    static func log(
        site: String, type: String, appState: String, attempt: Int, delay: Double,
        totalTime: Double, result: String, windowCount: Int = 0, display: String = "",
        size: String = "", detail: String = ""
    ) {
        #if DEBUG
            fileLock.lock()
            defer { fileLock.unlock() }

            // 로그 디렉토리 생성
            try? FileManager.default.createDirectory(
                atPath: logDir, withIntermediateDirectories: true)

            // 일별 파일명
            let dateStr = ISO8601DateFormatter.string(
                from: Date(), timeZone: .current, formatOptions: [.withFullDate])
            let filePath = (logDir as NSString).appendingPathComponent("resize_\(dateStr).csv")

            // 헤더 (파일 없으면 추가)
            if !FileManager.default.fileExists(atPath: filePath) {
                let header =
                    "timestamp,site,type,app_state,attempt,delay,total_time,result,window_count,display,size,detail\n"
                try? header.write(toFile: filePath, atomically: true, encoding: .utf8)
            }

            // CSV 행 추가
            let timestamp = ISO8601DateFormatter.string(
                from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime])
            let row =
                "\(timestamp),\(csvSafe(site)),\(type),\(appState),\(attempt),\(String(format: "%.2f", delay)),\(String(format: "%.2f", totalTime)),\(result),\(windowCount),\(csvSafe(display)),\(csvSafe(size)),\(csvSafe(detail))\n"

            if let handle = FileHandle(forWritingAtPath: filePath) {
                handle.seekToEndOfFile()
                handle.write(row.data(using: .utf8) ?? Data())
                handle.closeFile()
            }
        #endif
    }
}
