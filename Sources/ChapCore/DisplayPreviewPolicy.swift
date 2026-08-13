import Foundation

public enum DisplayPreviewPolicy {
    public static let topologyHeight: CGFloat = 58
    public static let compactTopologyHeight: CGFloat = 96
    public static let splitPreviewMinimumWidth: CGFloat = 420
    public static let detailHeight: CGFloat = 204
    public static let detailContentInset: CGFloat = 20
    public static let minimumNamedMonitorWidth: CGFloat = 86
    public static let minimumNamedMonitorHeight: CGFloat = 40

    public static func overviewLabel(
        displayName: String,
        displayIndex: Int,
        renderedSize: CGSize
    ) -> String {
        guard renderedSize.width >= minimumNamedMonitorWidth,
            renderedSize.height >= minimumNamedMonitorHeight
        else {
            return "\(displayIndex + 1)"
        }
        return displayName
    }

    public static func detailDisplaySize(
        displaySize: CGSize,
        availableSize: CGSize
    ) -> CGSize {
        guard displaySize.width > 0, displaySize.height > 0,
            availableSize.width > 0, availableSize.height > 0
        else {
            return .zero
        }

        let contentWidth = max(0, availableSize.width - detailContentInset * 2)
        let contentHeight = max(0, availableSize.height - detailContentInset * 2)
        let scale = min(contentWidth / displaySize.width, contentHeight / displaySize.height)
        return CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
    }
}
