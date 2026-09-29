import AVFoundation
import os

/// 노치 거울 위젯이 쓰는 단일 카메라 세션.
/// 세션 구성·시작·정지는 블로킹 호출이라 전용 직렬 큐에서만 수행한다.
/// 카메라 켜짐 표시등은 세션이 실행 중일 때만 켜진다.
final class MirrorCamera: @unchecked Sendable {
    static let shared = MirrorCamera()

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.mingyupark.Chap.mirror", qos: .userInitiated)
    private var isConfigured = false

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

    /// 미리보기 레이어를 세션에 연결한다. 연결은 세션 구성을 바꾸므로 start/stop과 같은
    /// 직렬 큐에서 해야 한다. 메인 스레드에서 연결하는 동안 다른 스레드가 startRunning을
    /// 부르면 AVFoundation이 NSFastEnumerationMutation 예외로 앱을 종료한다 (2.2.0 크래시).
    /// 연결이 끝나면 메인 스레드에서 completion을 부른다.
    func attach(_ layer: AVCaptureVideoPreviewLayer, completion: @escaping () -> Void) {
        queue.async { [self] in
            configureIfNeeded()
            layer.session = session
            DispatchQueue.main.async(execute: completion)
        }
    }

    func start() {
        queue.async { [self] in
            guard Self.access == .authorized else { return }
            configureIfNeeded()
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
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
