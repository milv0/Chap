import Foundation

/// 리사이즈 결과를 CSV 파일로 자동 수집하는 로거
/// 저장 위치: ~/.chap/logs/resize_YYYY-MM-DD.csv
enum ResizeLogger {
    private static let logDir: String = {
        let sourceFile = #file
        let componets = sourceFile.components(separatedBy: "/Sources/")
        return (componets.first ?? NSString(string: "~/.chap").expandingTildeInPath) + "/logs"
    }()

    /// 리사이즈 결과 기록
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
    static func log(site: String, type: String, appState: String, attempt: Int, delay: Double, totalTime: Double, result: String, windowCount: Int = 0, display: String = "", size: String = "") {
        // 로그 디렉토리 생성
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        // 일별 파일명
        let dateStr = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        let filePath = (logDir as NSString).appendingPathComponent("resize_\(dateStr).csv")

        // 헤더 (파일 없으면 추가)
        if !FileManager.default.fileExists(atPath: filePath) {
            let header = "timestamp,site,type,app_state,attempt,delay,total_time,result,window_count,display,size\n"
            try? header.write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        // CSV 행 추가
        let timestamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime])
        let row = "\(timestamp),\(site),\(type),\(appState),\(attempt),\(String(format: "%.2f", delay)),\(String(format: "%.2f", totalTime)),\(result),\(windowCount),\(display),\(size)\n"

        if let handle = FileHandle(forWritingAtPath: filePath) {
            handle.seekToEndOfFile()
            handle.write(row.data(using: .utf8) ?? Data())
            handle.closeFile()
        }
    }
}
