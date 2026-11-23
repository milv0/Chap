import Foundation

/// 폴더 하나에 파일이 들어오거나 이름이 바뀌는 것을 지켜본다(Notch Glow의 새 파일 알림).
///
/// 커널 이벤트(`DispatchSource` vnode)라 폴링하지 않고, 아무 일이 없으면 CPU를 쓰지 않는다. 폴더 안 파일 목록은 읽지
/// 않는다. 읽기는 알림을 받은 쪽이 선반 스캔(`ScreenshotShelf`·`DownloadsShelf`)으로 한다.
/// 다운로드는 받는 동안(.crdownload 등) 여러 번 바뀌므로, 마지막 변화 뒤 `settleDelay`만큼 조용해지면 한 번만 알린다.
/// 메인 스레드에서 만들고 멈추며, `onChange`도 메인 스레드에서 불린다.
final class FolderChangeWatcher {
    let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private static let settleDelay: TimeInterval = 1

    /// 폴더를 열 수 없으면(없음·권한) nil.
    init?(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .link], queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleChange() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    deinit { stop() }

    func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
    }

    private func scheduleChange() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: work)
    }
}
