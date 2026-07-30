import Combine
import Contacts
import Foundation
import SwiftData

/// Protocol-backed seams keep production services replaceable in previews,
/// unit tests, and UI tests. Local features intentionally have no dependency on
/// Firebase configuration.
@MainActor
protocol LocalPersistenceProviding: AnyObject {
    @discardableResult func save(_ context: ModelContext) -> Bool
}

@MainActor
final class LocalPersistenceFailureReporter: ObservableObject, LocalPersistenceProviding {
    static let shared = LocalPersistenceFailureReporter()

    @Published private(set) var message: String?

    private init() {}

    @discardableResult
    func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            // Do not include record content or underlying database paths in UI.
            message = "Changes could not be saved locally. Your editor remains open so you can try again."
            return false
        }
    }

    func clearMessage() {
        message = nil
    }

    func reportFailure() {
        // Keep repository/query failures as safe and actionable as save
        // failures; neither may expose record content or local paths.
        message = "Changes could not be completed locally. Please try again."
    }
}

@MainActor
final class AppEnvironment: ObservableObject {
    let authentication: AuthenticationStateStore
    let appCheck: AppCheckStateStore
    let captureService: any CaptureImporting
    let persistence: any LocalPersistenceProviding
    let aiGateway: any AIExtracting
    let calendarService: any CalendarService
    let voiceCaptureService: any VoiceCaptureServicing
    let contactImportService: any ContactImporting

    init(
        authentication: AuthenticationStateStore = AuthenticationStateStore(),
        appCheck: AppCheckStateStore = AppCheckStateStore(),
        captureService: any CaptureImporting = LocalCaptureService(),
        persistence: any LocalPersistenceProviding = LocalPersistenceFailureReporter.shared,
        aiGateway: (any AIExtracting)? = nil,
        calendarService: any CalendarService = EventKitCalendarService(),
        voiceCaptureService: any VoiceCaptureServicing = DeviceVoiceCaptureService(),
        contactImportService: any ContactImporting = DeviceContactImportService()
    ) {
        self.authentication = authentication
        self.appCheck = appCheck
        self.captureService = captureService
        self.persistence = persistence
        self.aiGateway = aiGateway ?? Self.defaultAIGateway()
        self.calendarService = calendarService
        self.voiceCaptureService = voiceCaptureService
        self.contactImportService = contactImportService
    }

    func refreshProtectedServices() async {
        authentication.refresh()
        await appCheck.refreshIfNeeded()
    }

    private static func defaultAIGateway() -> any AIExtracting {
        AdaptiveAIGateway()
    }

    /// UI tests must not open system permission prompts or talk to a device
    /// calendar, microphone, contacts database, or Firebase. The app still
    /// exercises its normal SwiftUI navigation and SwiftData workflows against
    /// an in-memory container selected by `SocialBrainModelContainerFactory`.
    static func makeForCurrentRuntime() -> AppEnvironment {
        guard ProcessInfo.processInfo.environment["SOCIAL_BRAIN_UI_TESTING"] == "YES" else {
            return AppEnvironment()
        }
        return AppEnvironment(
            aiGateway: LocalOnlyAIGateway(),
            calendarService: UITestCalendarService(),
            voiceCaptureService: UITestVoiceCaptureService(),
            contactImportService: UITestContactImportService()
        )
    }
}

@MainActor
private final class UITestCalendarService: CalendarService {
    var authorizationState: CalendarAuthorizationState { .unavailable }

    func requestFullAccess() async -> CalendarAuthorizationState { .unavailable }
    func requestWriteOnlyAccess() async -> CalendarAuthorizationState { .unavailable }
    func events(from startDate: Date, through endDate: Date) throws -> [DeviceCalendarEvent] {
        throw CalendarServiceError.calendarUnavailable
    }
    func save(_ draft: CalendarEventDraft) throws -> DeviceCalendarEvent {
        throw CalendarServiceError.calendarUnavailable
    }
    func deleteSocialBrainExportedEvent(identifier: String, calendarIdentifier: String, ownerID: UUID) throws {
        throw CalendarServiceError.calendarUnavailable
    }
}

@MainActor
private final class UITestVoiceCaptureService: VoiceCaptureServicing {
    var state: VoiceCaptureState { .idle }
    var microphonePermission: VoicePermissionState { .unavailable }
    var speechRecognitionPermission: VoicePermissionState { .unavailable }

    func requestMicrophoneAccess() async -> VoicePermissionState { .unavailable }
    func requestSpeechRecognitionAccess() async -> VoicePermissionState { .unavailable }
    func startRecording() throws { throw VoiceCaptureError.microphoneAccessRequired }
    func stopRecording() throws -> VoiceRecording { throw VoiceCaptureError.noActiveRecording }
    func cancelRecording() {}
    func play(_ recording: VoiceRecording) throws { throw VoiceCaptureError.playbackCouldNotStart }
    func stopPlayback() {}
    func discardRecording(_ recording: VoiceRecording) {}
    func transcribe(_ recording: VoiceRecording) async -> VoiceTranscriptionResult {
        .unavailable("On-device transcription is unavailable in UI tests.")
    }
}

@MainActor
private final class UITestContactImportService: ContactImporting {
    var authorizationState: ContactAuthorizationState { .unavailable }

    func requestAccess() async -> ContactAuthorizationState { .unavailable }
    func candidates(from contacts: [CNContact]) -> [ContactImportCandidate] { [] }
}
