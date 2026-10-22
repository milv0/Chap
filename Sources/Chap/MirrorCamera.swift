import AVFoundation
import os

/// 느린 카메라 연결 작업과 UI 닫힘 사이의 순서를 보장한다. 새 시작이나 취소가 생기면 이전 token은 무효다.
final class MirrorCaptureIntent: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt = 0
    private var wantsCapture = false

    func begin() -> UInt {
        lock.withLock {
            generation &+= 1
            wantsCapture = true
            return generation
        }
    }

    func cancel() {
        lock.withLock {
            generation &+= 1
            wantsCapture = false
        }
    }

    /// 해당 token이 여전히 현재 미리보기일 때만 취소한다. 이전 뷰의 늦은 teardown은 새 뷰를 끄지 않는다.
    @discardableResult
    func cancel(token: UInt) -> Bool {
        lock.withLock {
            guard wantsCapture, token == generation else { return false }
            generation &+= 1
            wantsCapture = false
            return true
        }
    }

    func permits(_ token: UInt) -> Bool {
        lock.withLock { wantsCapture && token == generation }
    }
}

/// 노치 거울 위젯이 쓰는 단일 카메라 세션.
/// 세션 구성·시작·정지는 블로킹 호출이라 전용 직렬 큐에서만 수행한다.
/// 카메라 켜짐 표시등은 세션이 실행 중일 때만 켜진다.
final class MirrorCamera: @unchecked Sendable {
    static let shared = MirrorCamera()

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.mingyupark.Chap.mirror", qos: .userInitiated)
    private var isConfigured = false
    private let captureIntent = MirrorCaptureIntent()

    private init() {}

    static var access: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    /// 내장 카메라를 우선하고, 없으면 시스템 기본 카메라를 쓴다.
    static var device: AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified
        ).devices.first ?? AVCaptureDevice.default(for: .video)
    }

    static var hasCamera: Bool { device != nil }

    static var displayState: MirrorDisplayState {
        MirrorPolicy.displayState(access: access, hasCamera: hasCamera)
    }

    /// 사용자가 거울 위젯의 버튼을 눌렀을 때만 권한을 요청한다.
    static func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// 미리보기 레이어를 세션에 연결하고, 아직 사용자가 거울을 열어 둔 경우에만 캡처를 시작한다.
    /// 연결은 세션 구성을 바꾸므로 start/stop과 같은 직렬 큐에서 해야 한다. 메인 스레드에서 연결하는 동안
    /// 다른 스레드가 startRunning을 부르면 AVFoundation이 NSFastEnumerationMutation 예외로 앱을 종료한다.
    /// `stop()`은 즉시 token을 무효화하므로 느린 초기 구성 중 UI가 닫혀도 뒤늦게 카메라가 켜지지 않는다.
    @discardableResult
    func attachAndStart(
        _ layer: AVCaptureVideoPreviewLayer, preparePreview: @escaping () -> Void
    ) -> UInt {
        let token = captureIntent.begin()
        queue.async { [self] in
            configureIfNeeded()
            layer.session = session
            DispatchQueue.main.async { [self] in
                preparePreview()
                queue.async { [self] in
                    guard captureIntent.permits(token), Self.access == .authorized else { return }
                    if !session.isRunning { session.startRunning() }
                }
            }
        }
        return token
    }

    /// 특정 미리보기가 내려갈 때의 정지. 이미 더 새 미리보기가 열렸으면 그 세션은 건드리지 않는다.
    func stop(token: UInt) {
        guard captureIntent.cancel(token: token) else { return }
        stopSession()
    }

    /// 사용자 끄기·패널 닫기처럼 현재 미리보기를 조건 없이 끝낸다.
    func stop() {
        captureIntent.cancel()
        stopSession()
    }

    private func stopSession() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured, let device = Self.device else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // 작은 미리보기라 고해상도가 필요 없다. 발열과 전력을 줄인다.
        if session.canSetSessionPreset(.medium) { session.sessionPreset = .medium }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return }
            session.addInput(input)
            isConfigured = true
        } catch {
            Log.app.error(
                "Mirror camera input failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
