import AVFoundation
import Combine
import Foundation
import Speech

enum VoicePermissionState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable

    var canUse: Bool { self == .authorized }
}

struct VoicePermissionStatus: Equatable {
    let microphone: VoicePermissionState
    let speechRecognition: VoicePermissionState

    var canRecord: Bool { microphone.canUse }
    var canTranscribe: Bool { microphone.canUse && speechRecognition.canUse }
}

enum VoiceCaptureState: Equatable {
    case idle
    case recording
    case recorded
    case playing
}

struct VoiceRecording: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    let duration: TimeInterval
    let fileExtension: String
    let mimeType: String
}

enum VoiceTranscriptionResult: Equatable {
    case transcript(String)
    case unavailable(String)
}

enum VoiceCaptureError: Error, Equatable, LocalizedError {
    case microphoneAccessRequired
    case noActiveRecording
    case recordingCouldNotStart
    case recordingFileMissing
    case recordingTooLong
    case recordingTooLarge
    case playbackCouldNotStart

    var errorDescription: String? {
        switch self {
        case .microphoneAccessRequired:
            return "Allow microphone access before recording a voice capture."
        case .noActiveRecording:
            return "There is no voice recording in progress."
        case .recordingCouldNotStart:
            return "Voice recording could not start on this device."
        case .recordingFileMissing:
            return "The temporary voice recording is no longer available."
        case .recordingTooLong:
            return "Voice recordings are limited to five minutes. This recording was discarded."
        case .recordingTooLarge:
            return "Voice recordings are limited to 25 MB. This recording was discarded."
        case .playbackCouldNotStart:
            return "The voice recording could not be played."
        }
    }
}

/// Audio capture is intentionally isolated behind a protocol so UI and tests
/// can use a deterministic fake without microphone, Speech, or AVFoundation.
@MainActor
protocol VoiceCaptureServicing: AnyObject {
    var state: VoiceCaptureState { get }
    var microphonePermission: VoicePermissionState { get }
    var speechRecognitionPermission: VoicePermissionState { get }

    func requestMicrophoneAccess() async -> VoicePermissionState
    func requestSpeechRecognitionAccess() async -> VoicePermissionState
    func startRecording() throws
    func stopRecording() throws -> VoiceRecording
    func cancelRecording()
    func play(_ recording: VoiceRecording) throws
    func stopPlayback()
    func discardRecording(_ recording: VoiceRecording)
    func transcribe(_ recording: VoiceRecording) async -> VoiceTranscriptionResult
}

@MainActor
final class DeviceVoiceCaptureService: NSObject, VoiceCaptureServicing {
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var activeRecordingID: UUID?
    private var activeRecordingURL: URL?
    private var latestRecording: VoiceRecording?
    private var transcriptionTask: SFSpeechRecognitionTask?

    private(set) var state: VoiceCaptureState = .idle

    init(fileManager: FileManager = .default, temporaryDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory ?? Self.defaultTemporaryDirectory(fileManager: fileManager)
        super.init()
        try? ensureTemporaryDirectoryExists()
        removeExpiredTemporaryRecordings()
    }

    var microphonePermission: VoicePermissionState {
        Self.microphonePermissionState()
    }

    var speechRecognitionPermission: VoicePermissionState {
        Self.speechPermissionState(SFSpeechRecognizer.authorizationStatus())
    }

    func requestMicrophoneAccess() async -> VoicePermissionState {
        guard microphonePermission == .notDetermined else { return microphonePermission }
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted ? .authorized : Self.microphonePermissionState())
            }
        }
    }

    func requestSpeechRecognitionAccess() async -> VoicePermissionState {
        guard speechRecognitionPermission == .notDetermined else { return speechRecognitionPermission }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return Self.speechPermissionState(status)
    }

    func startRecording() throws {
        guard microphonePermission.canUse else { throw VoiceCaptureError.microphoneAccessRequired }
        guard state != .recording else { return }

        if let latestRecording {
            discardRecording(latestRecording)
        }
        try configureRecordingSession()
        let id = UUID()
        let url = try newRecordingURL(for: id)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 64_000
        ]
        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.prepareToRecord() else {
                try? fileManager.removeItem(at: url)
                throw VoiceCaptureError.recordingCouldNotStart
            }
            // Bound temporary local recording time as well as the later import
            // path, so an unattended recorder cannot grow indefinitely.
            recorder.record(forDuration: CaptureInputLimits.maximumVoiceRecordingDuration)
            guard recorder.isRecording else {
                try? fileManager.removeItem(at: url)
                throw VoiceCaptureError.recordingCouldNotStart
            }
            self.recorder = recorder
            activeRecordingID = id
            activeRecordingURL = url
            protectFileIfSupported(url)
            state = .recording
        } catch let error as VoiceCaptureError {
            throw error
        } catch {
            try? fileManager.removeItem(at: url)
            throw VoiceCaptureError.recordingCouldNotStart
        }
    }

    func stopRecording() throws -> VoiceRecording {
        guard let recorder, let id = activeRecordingID, let url = activeRecordingURL else {
            throw VoiceCaptureError.noActiveRecording
        }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        activeRecordingID = nil
        activeRecordingURL = nil
        guard fileManager.fileExists(atPath: url.path) else {
            state = .idle
            throw VoiceCaptureError.recordingFileMissing
        }
        guard duration <= CaptureInputLimits.maximumVoiceRecordingDuration else {
            discardTemporaryRecording(at: url)
            state = .idle
            throw VoiceCaptureError.recordingTooLong
        }
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard byteCount <= CaptureInputLimits.maximumAudioBytes else {
            discardTemporaryRecording(at: url)
            state = .idle
            throw VoiceCaptureError.recordingTooLarge
        }
        let recording = VoiceRecording(
            id: id,
            fileURL: url,
            duration: duration,
            fileExtension: "m4a",
            mimeType: "audio/mp4"
        )
        latestRecording = recording
        state = .recorded
        return recording
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        if let activeRecordingURL {
            try? fileManager.removeItem(at: activeRecordingURL)
        }
        activeRecordingID = nil
        activeRecordingURL = nil
        state = latestRecording == nil ? .idle : .recorded
        deactivateAudioSession()
    }

    func play(_ recording: VoiceRecording) throws {
        guard fileManager.fileExists(atPath: recording.fileURL.path) else {
            throw VoiceCaptureError.recordingFileMissing
        }
        stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: recording.fileURL)
            player.delegate = self
            guard player.play() else { throw VoiceCaptureError.playbackCouldNotStart }
            self.player = player
            latestRecording = recording
            state = .playing
        } catch let error as VoiceCaptureError {
            throw error
        } catch {
            throw VoiceCaptureError.playbackCouldNotStart
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        state = latestRecording == nil ? .idle : .recorded
        deactivateAudioSession()
    }

    func discardRecording(_ recording: VoiceRecording) {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        if state == .playing {
            stopPlayback()
        }
        if activeRecordingID == recording.id {
            cancelRecording()
        }
        try? fileManager.removeItem(at: recording.fileURL)
        if latestRecording?.id == recording.id {
            latestRecording = nil
            state = .idle
        }
    }

    func transcribe(_ recording: VoiceRecording) async -> VoiceTranscriptionResult {
        guard transcriptionTask == nil else {
            return .unavailable("Transcription is already in progress. Add notes manually or wait for it to finish.")
        }
        guard speechRecognitionPermission.canUse else {
            return .unavailable("Speech recognition is unavailable. Add a transcript or notes manually.")
        }
        guard fileManager.fileExists(atPath: recording.fileURL.path),
              let recognizer = SFSpeechRecognizer(), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition
        else {
            return .unavailable("On-device transcription is unavailable. Add a transcript or notes manually.")
        }

        let request = SFSpeechURLRecognitionRequest(url: recording.fileURL)
        request.requiresOnDeviceRecognition = true
        return await withCheckedContinuation { continuation in
            var hasCompleted = false
            transcriptionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard !hasCompleted else { return }
                if let result, result.isFinal {
                    hasCompleted = true
                    Task { @MainActor [weak self] in self?.transcriptionTask = nil }
                    let transcript = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(
                        returning: transcript.isEmpty
                            ? .unavailable("No speech was detected. Add a transcript or notes manually.")
                            : .transcript(transcript)
                    )
                } else if error != nil {
                    hasCompleted = true
                    Task { @MainActor [weak self] in self?.transcriptionTask = nil }
                    continuation.resume(returning: .unavailable("Transcription could not finish. Add a transcript or notes manually."))
                }
            }
        }
    }

    private func configureRecordingSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    private func ensureTemporaryDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: temporaryDirectory.path) else { return }
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        protectFileIfSupported(temporaryDirectory)
    }

    private func newRecordingURL(for id: UUID) throws -> URL {
        try ensureTemporaryDirectoryExists()
        return temporaryDirectory.appendingPathComponent("\(id.uuidString.lowercased()).m4a", isDirectory: false)
    }

    private func discardTemporaryRecording(at url: URL) {
        try? fileManager.removeItem(at: url)
        latestRecording = nil
        deactivateAudioSession()
    }

    private func removeExpiredTemporaryRecordings() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let expiration = Date().addingTimeInterval(-24 * 60 * 60)
        for url in contents {
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if (modified ?? .distantPast) < expiration {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func defaultTemporaryDirectory(fileManager: FileManager) -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("SocialBrainVoice", isDirectory: true)
    }

    private static func microphonePermissionState() -> VoicePermissionState {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined: return .notDetermined
        case .granted: return .authorized
        case .denied: return .denied
        @unknown default: return .unavailable
        }
    }

    private static func speechPermissionState(_ status: SFSpeechRecognizerAuthorizationStatus) -> VoicePermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }

    private func protectFileIfSupported(_ url: URL) {
#if os(iOS)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
#endif
    }
}

extension DeviceVoiceCaptureService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.player = nil
            self.state = self.latestRecording == nil ? .idle : .recorded
            self.deactivateAudioSession()
        }
    }
}

/// Observable adapter for SwiftUI. It owns the temporary recording until the
/// composer encrypts it or the person explicitly cancels/discards it.
@MainActor
final class VoiceCaptureViewModel: ObservableObject {
    @Published private(set) var state: VoiceCaptureState
    @Published private(set) var permissionStatus: VoicePermissionStatus
    @Published private(set) var recording: VoiceRecording?
    @Published private(set) var message: String?

    private let service: any VoiceCaptureServicing

    init(service: any VoiceCaptureServicing = DeviceVoiceCaptureService()) {
        self.service = service
        state = service.state
        permissionStatus = VoicePermissionStatus(
            microphone: service.microphonePermission,
            speechRecognition: service.speechRecognitionPermission
        )
    }

    func requestPermissions() async {
        _ = await service.requestMicrophoneAccess()
        _ = await service.requestSpeechRecognitionAccess()
        refresh()
    }

    func startRecording() {
        if let recording {
            service.discardRecording(recording)
            self.recording = nil
        }
        do {
            try service.startRecording()
            message = nil
        } catch {
            message = error.localizedDescription
        }
        refresh()
    }

    func stopRecording() {
        do {
            recording = try service.stopRecording()
            message = nil
        } catch {
            message = error.localizedDescription
        }
        refresh()
    }

    func cancelActiveRecording() {
        service.cancelRecording()
        refresh()
    }

    func discardRecording() {
        if let recording {
            service.discardRecording(recording)
        } else {
            service.cancelRecording()
        }
        recording = nil
        message = nil
        refresh()
    }

    func togglePlayback() {
        guard let recording else { return }
        if state == .playing {
            service.stopPlayback()
        } else {
            do {
                try service.play(recording)
                message = nil
            } catch {
                message = error.localizedDescription
            }
        }
        refresh()
    }

    func transcribe() async -> String? {
        guard let recording else { return nil }
        switch await service.transcribe(recording) {
        case .transcript(let value):
            message = nil
            refresh()
            return value
        case .unavailable(let message):
            self.message = message
            refresh()
            return nil
        }
    }

    private func refresh() {
        state = service.state
        permissionStatus = VoicePermissionStatus(
            microphone: service.microphonePermission,
            speechRecognition: service.speechRecognitionPermission
        )
    }
}
