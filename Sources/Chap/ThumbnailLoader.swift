import AppKit

/// 노치 파일 썸네일 공용 로더.
///
/// 파일 stat·CGImageSource 디코딩을 utility queue에서 수행하고, URL+수정시각+
/// 픽셀 크기로 캐시해 패널 재오픈 때 같은 이미지를 다시 디코딩하지 않는다.
enum ThumbnailLoader {
    private static let queue = DispatchQueue(
        label: "com.mingyupark.Chap.thumbnail", qos: .utility,
        attributes: .concurrent)
    private static let cache = NSCache<NSString, NSImage>()
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "tiff", "gif",
    ]

    /// 이미지 파일이면 다운샘플 썸네일, 아니면 nil.
    @MainActor
    static func image(for url: URL, maxPixelSize: Int) async -> NSImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard imageExtensions.contains(url.pathExtension.lowercased()) else {
                    continuation.resume(returning: nil)
                    return
                }
                let modified =
                    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
                let key = "\(url.path)|\(modified)|\(maxPixelSize)" as NSString
                if let cached = cache.object(forKey: key) {
                    continuation.resume(returning: cached)
                    return
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                ]
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                    let cgImage = CGImageSourceCreateThumbnailAtIndex(
                        source, 0, options as CFDictionary)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                let image = NSImage(cgImage: cgImage, size: .zero)
                cache.setObject(image, forKey: key)
                continuation.resume(returning: image)
            }
        }
    }
}

/// 노치 Apps 칸의 앱 아이콘 로더. NSWorkspace 아이콘 조회를 utility queue에서 하고
/// 경로별로 캐시해 패널을 다시 열 때 즉시 보인다.
enum AppIconLoader {
    private static let queue = DispatchQueue(label: "com.mingyupark.Chap.appicon", qos: .utility)
    private static let cache = NSCache<NSString, NSImage>()

    static func cachedIcon(forAppPath path: String) -> NSImage? {
        cache.object(forKey: expanded(path) as NSString)
    }

    @MainActor
    static func icon(forAppPath path: String) async -> NSImage? {
        let path = expanded(path)
        if let cached = cache.object(forKey: path as NSString) { return cached }
        return await withCheckedContinuation { continuation in
            queue.async {
                guard FileManager.default.fileExists(atPath: path) else {
                    continuation.resume(returning: nil)
                    return
                }
                let icon = NSWorkspace.shared.icon(forFile: path)
                cache.setObject(icon, forKey: path as NSString)
                continuation.resume(returning: icon)
            }
        }
    }

    private static func expanded(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
