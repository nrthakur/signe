import AVFoundation
import CoreMedia
import CoreVideo

// MARK: - Camera Frame

struct CameraFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let timestamp: Double
    let width: Int
    let height: Int
}

// MARK: - Camera Permission

enum CameraPermission: Sendable {
    case notDetermined
    case granted
    case denied
}

// MARK: - Camera Service

/// Thread-safety: mutable state is accessed only on `sessionQueue`.
/// `captureSession` is read from main thread for the preview layer (safe per Apple docs).
final class CameraService: @unchecked Sendable {
    let captureSession = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let delegateQueue = DispatchQueue(label: "com.signe.camera.frames", qos: .userInteractive)
    private let sessionQueue = DispatchQueue(label: "com.signe.camera.session")
    private var delegate: CameraDelegate?

    private var frameContinuation: AsyncStream<CameraFrame>.Continuation?
    private var isConfigured = false
    private var isRunning = false

    // MARK: - Frame Stream

    var frames: AsyncStream<CameraFrame> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let queue = self.sessionQueue
            queue.async { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                self.frameContinuation?.finish()
                self.frameContinuation = continuation
            }

            continuation.onTermination = { [weak self] _ in
                let queue = self?.sessionQueue
                queue?.async { [weak self] in
                    guard let self else { return }
                    self.frameContinuation = nil
                }
            }
        }
    }

    // MARK: - Permission

    static func checkPermission() -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Configuration

    func configure() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: ())
                    return
                }

                do {
                    try self.configureSessionIfNeeded()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Start / Stop

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured, !self.isRunning else { return }
            self.captureSession.startRunning()
            self.isRunning = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }
            self.captureSession.stopRunning()
            self.isRunning = false
            self.frameContinuation?.finish()
            self.frameContinuation = nil
        }
    }

    // MARK: - Internal Configuration

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else { return }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Medium preset keeps detection responsive on older devices while preserving enough detail.
        if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
        } else {
            captureSession.sessionPreset = .high
        }

        // Front camera
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            throw CameraError.noCameraAvailable
        }

        // Target 30 FPS to reduce thermal load and frame backlog.
        do {
            try device.lockForConfiguration()
            let targetDuration = CMTime(value: 1, timescale: 30)
            if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 30 }) {
                device.activeVideoMinFrameDuration = targetDuration
                device.activeVideoMaxFrameDuration = targetDuration
            }
            device.unlockForConfiguration()
        } catch {
            // Frame rate tuning is best-effort; continue with default if unavailable.
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        captureSession.addInput(input)

        // Video output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard captureSession.canAddOutput(videoOutput) else {
            throw CameraError.cannotAddOutput
        }
        captureSession.addOutput(videoOutput)

        // Set up delegate
        let cameraDelegate = CameraDelegate { [weak self] frame in
            guard let self else { return }
            self.sessionQueue.async { [weak self] in
                guard let self else { return }
                self.frameContinuation?.yield(frame)
            }
        }
        delegate = cameraDelegate
        videoOutput.setSampleBufferDelegate(cameraDelegate, queue: delegateQueue)

        // Configure the data output connection for portrait buffers.
        // Do NOT mirror — Vision needs the natural image; the preview layer auto-mirrors.
        if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        isConfigured = true
    }
}

// MARK: - Camera Delegate

private final class CameraDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onFrame: @Sendable (CameraFrame) -> Void

    init(onFrame: @escaping @Sendable (CameraFrame) -> Void) {
        self.onFrame = onFrame
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let frame = CameraFrame(
            pixelBuffer: pixelBuffer,
            timestamp: timestamp,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        onFrame(frame)
    }
}

// MARK: - Camera Error

enum CameraError: Error, LocalizedError {
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: return "No camera available on this device"
        case .cannotAddInput: return "Cannot configure camera input"
        case .cannotAddOutput: return "Cannot configure video output"
        case .permissionDenied: return "Camera access is required to practice ASL"
        }
    }
}
