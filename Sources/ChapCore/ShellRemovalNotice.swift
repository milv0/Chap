import Foundation

/// 2.1에서 Shell launch type을 제거하며 사용자에게 보여주는 안내 문구.
/// 문구 조합을 UI에서 분리해 단위 테스트로 고정한다.
public enum ShellRemovalNotice {
    /// 목록에 이름을 모두 나열하는 최대 개수. 넘치면 "외 N개"로 줄인다.
    public static let maxListedNames = 4

    public static let title = "Shell scripts are no longer supported"

    /// 앱 실행 중 설정에서 Shell 항목을 걸러낸 뒤 보여주는 안내.
    /// - Parameter backupPath: 원본 보관 경로. 백업에 실패했으면 nil.
    public static func migrationMessage(removedNames: [String], backupPath: String?) -> String {
        var lines = [
            "Chap now focuses on opening windows, so Shell launchables were removed "
                + "from your configuration:",
            "",
            nameList(removedNames),
        ]
        if let backupPath {
            lines += ["", "Your previous configuration was saved to \(displayPath(backupPath))."]
        } else {
            lines += [
                "",
                "Chap could not back up your previous configuration, so it left the file "
                    + "unchanged. Saving settings will remove these items permanently.",
            ]
        }
        return lines.joined(separator: "\n")
    }

    /// Shell 항목이 든 설정 가져오기를 거부할 때 보여주는 안내.
    public static func importRejectionMessage(removedNames: [String]) -> String {
        [
            "This file contains Shell launchables, which Chap no longer supports:",
            "",
            nameList(removedNames),
            "",
            "Remove these items from the file and import it again. Nothing was changed.",
        ].joined(separator: "\n")
    }

    static func nameList(_ names: [String]) -> String {
        let listed = names.prefix(maxListedNames).map { "• \($0)" }
        let remaining = names.count - listed.count
        return (listed + (remaining > 0 ? ["• and \(remaining) more"] : []))
            .joined(separator: "\n")
    }

    /// 홈 디렉터리를 `~`로 줄여 보여준다.
    static func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
