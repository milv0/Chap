import CoreGraphics
import Foundation

/// 화면 영역 텍스트 인식(드래그 → 인식 → 복사)의 순수 규칙.
/// 캡처·Vision·창 처리와 분리해 좌표 변환, 줄 정렬, 안내 문구를 테스트로 고정한다.
public enum TextRecognitionPolicy {
    /// 이보다 작은 드래그는 실수로 보고 취소한다 (가로·세로 각각, pt).
    public static let minimumSelectionSide: CGFloat = 6
    /// 복사 알림에 보여줄 첫 줄 최대 글자 수.
    public static let previewLength = 32
    /// Vision 인식 언어. 한국어와 영어가 섞인 글을 함께 읽는다.
    public static let recognitionLanguages = ["ko-KR", "en-US"]

    /// 드래그 시작·끝 점으로 선택 사각형을 만든다. 너무 작으면 nil (취소).
    public static func selectionRect(from start: CGPoint, to end: CGPoint) -> CGRect? {
        let rect = CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(end.x - start.x), height: abs(end.y - start.y))
        guard rect.width >= minimumSelectionSide, rect.height >= minimumSelectionSide
        else { return nil }
        return rect
    }

    /// AppKit 전역 좌표(원점 왼쪽 아래)의 사각형을 해당 디스플레이 기준 캡처 좌표
    /// (원점 왼쪽 위, pt)로 바꾼다. ScreenCaptureKit `sourceRect`가 이 좌표를 쓴다.
    public static func captureRect(forGlobalRect rect: CGRect, screenFrame: CGRect) -> CGRect {
        let clipped = rect.intersection(screenFrame)
        return CGRect(
            x: clipped.minX - screenFrame.minX,
            y: screenFrame.maxY - clipped.maxY,
            width: clipped.width, height: clipped.height)
    }

    /// 인식된 한 줄. `box`는 Vision 정규화 좌표(0~1, 원점 왼쪽 아래)다.
    public struct Line: Equatable, Sendable {
        public let text: String
        public let box: CGRect

        public init(text: String, box: CGRect) {
            self.text = text
            self.box = box
        }
    }

    /// Vision 결과를 사람이 읽는 순서(위→아래, 같은 줄이면 왼쪽→오른쪽)로 이어 붙인다.
    /// 세로 중심이 줄 높이의 절반 안쪽으로 겹치면 같은 줄로 보고 공백으로 잇는다.
    public static func joinedText(_ lines: [Line]) -> String {
        let cleaned = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !cleaned.isEmpty else { return "" }
        let sorted = cleaned.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Line]] = []
        for line in sorted {
            if let last = rows.last?.first,
                abs(last.box.midY - line.box.midY) < min(last.box.height, line.box.height) / 2
            {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return
            rows
            .map { row in
                row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
            }
            .joined(separator: "\n")
    }

    /// 복사 알림 문구. 첫 줄만 짧게 보여주고, 글자가 없으면 nil.
    public static func copiedMessage(for text: String) -> String? {
        let firstLine =
            text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !firstLine.isEmpty else { return nil }
        let preview =
            firstLine.count > previewLength
            ? String(firstLine.prefix(previewLength)) + "…" : firstLine
        let extraLines = text.split(whereSeparator: \.isNewline).count - 1
        switch extraLines {
        case ..<1: return "Copied: \(preview)"
        case 1: return "Copied: \(preview) (+1 line)"
        default: return "Copied: \(preview) (+\(extraLines) lines)"
        }
    }

    /// 전역 단축키 글자. ⌥⇧와 함께 눌러 영역 인식을 시작한다 (⌥T 사이트 단축키와 겹치지 않는다).
    public static let shortcutKey = "T"
    /// 메뉴·툴팁에 보여줄 단축키 표기.
    public static let shortcutLabel = "⌥⇧T"

    /// 인식된 글자가 없을 때의 안내.
    public static let noTextMessage = "No text found in that area"
}
