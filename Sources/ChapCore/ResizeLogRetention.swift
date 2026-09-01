import Foundation

/// Debug 리사이즈 진단 CSV(`resize_YYYY-MM-DD.csv`)의 보존 기간 판정 (순수 로직).
///
/// ResizeLogger가 시작 시 오래된 진단 파일을 정리할 때 사용한다.
/// 파일명 형식이 다르거나 날짜가 유효하지 않으면 보수적으로 삭제 대상에서 제외한다.
enum ResizeLogRetention {
    /// 기본 보존 기간(일). 이 기간을 지난 로그가 삭제 대상이 된다.
    static let defaultMaxAgeDays = 14

    /// 보존 기간이 지난 파일명만 반환한다.
    ///
    /// 기준일(`now`)의 자정에서 `maxAgeDays`를 뺀 날짜보다 **이전** 날짜의 파일이
    /// 삭제 대상이다. 정확히 `maxAgeDays`일 전 파일은 보존한다.
    static func staleFileNames(
        in fileNames: [String],
        now: Date,
        maxAgeDays: Int = defaultMaxAgeDays,
        calendar: Calendar = .current
    ) -> [String] {
        guard
            let cutoff = calendar.date(
                byAdding: .day, value: -maxAgeDays, to: calendar.startOfDay(for: now))
        else { return [] }
        return fileNames.filter { name in
            guard let date = logDate(fromFileName: name, calendar: calendar) else {
                return false
            }
            return date < cutoff
        }
    }

    /// `resize_YYYY-MM-DD.csv` 파일명에서 날짜를 추출한다. 형식이 다르면 nil.
    static func logDate(fromFileName fileName: String, calendar: Calendar = .current) -> Date? {
        let prefix = "resize_"
        let suffix = ".csv"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else { return nil }

        let dateText = fileName.dropFirst(prefix.count).dropLast(suffix.count)
        let parts = dateText.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }

        // 13월·32일 같은 값이 이웃 날짜로 정규화되는 것을 거부한다.
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            return nil
        }
        return date
    }
}
