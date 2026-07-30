import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum CaptureReviewDestination: String, Identifiable {
    case person
    case memory
    case reminder
    case event

    var id: String { rawValue }
}

@MainActor
struct CaptureWorkspaceView: View {
    @Query(sort: \CaptureRecord.createdAt, order: .reverse) private var allCaptures: [CaptureRecord]
    private let captureService: any CaptureImporting
    private let voiceCaptureService: any VoiceCaptureServicing
    private let contactService: any ContactImporting
    @State private var showingComposer = false
    @State private var showingContactImport = false

    init(
        captureService: any CaptureImporting = LocalCaptureService(),
        voiceCaptureService: any VoiceCaptureServicing = DeviceVoiceCaptureService(),
        contactService: any ContactImporting = DeviceContactImportService()
    ) {
        self.captureService = captureService
        self.voiceCaptureService = voiceCaptureService
        self.contactService = contactService
    }

    private var captures: [CaptureRecord] { allCaptures.filter(\.isVisibleInDefaultLists) }

    var body: some View {
        NavigationStack {
            List {
                Section("Review first") {
                    Label("AI suggestions are off until Account & AI is configured", systemImage: "lock.trianglebadge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text("You can still capture content locally and review it manually before it becomes a person, memory, reminder, or event.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Captures") {
                    if captures.isEmpty {
                        ContentUnavailableView(
                            "Nothing captured yet",
                            systemImage: "plus.circle",
                            description: Text("Save text, a selected photo or screenshot, a voice file, or a pasted email for local review.")
                        )
                    }
                    ForEach(captures) { capture in
                        NavigationLink {
                            CaptureDetailView(capture: capture, captureService: captureService)
                        } label: {
                            CaptureRow(capture: capture)
                        }
                    }
                }
            }
            .navigationTitle("Capture")
            .toolbar {
                Button("Contacts", systemImage: "person.crop.circle.badge.plus") {
                    showingContactImport = true
                }
                Button("Add", systemImage: "plus") { showingComposer = true }
            }
            .sheet(isPresented: $showingComposer) {
                CaptureComposerView(
                    captureService: LocalCaptureImportCoordinator(importer: captureService),
                    voiceCapture: VoiceCaptureViewModel(service: voiceCaptureService)
                )
            }
            .sheet(isPresented: $showingContactImport) {
                ContactImportReviewView(contactService: contactService)
            }
        }
    }
}

private struct CaptureRow: View {
    let capture: CaptureRecord

    private var kind: CaptureKind? { CaptureKind(rawValue: capture.type) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(capture.contentPreview ?? kind?.displayName ?? capture.type.capitalized)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(capture.processed ? "Reviewed" : "Needs review")
                    Text("•")
                    Text(capture.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        switch kind {
        case .photo: return "photo"
        case .screenshot: return "rectangle.on.rectangle"
        case .voice: return "waveform"
        case .email: return "envelope"
        case .sharedText: return "square.and.arrow.down"
        case .text, .none: return "text.alignleft"
        }
    }
}

@MainActor
struct CaptureComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    private let captureService: any CaptureImportCoordinating
    private let inputPreparer: any CaptureInputPreparing
    private let settingsOpener: any ApplicationSettingsOpening
    @StateObject private var voiceCapture: VoiceCaptureViewModel

    @State private var kind: CaptureKind = .text
    @State private var text = ""
    @State private var sourceLabel = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachment: PreparedCaptureAttachment?
    @State private var attachmentDescription = ""
    @State private var showingAudioImporter = false
    @State private var errorMessage: String?

    init(
        captureService: any CaptureImportCoordinating = LocalCaptureImportCoordinator(),
        inputPreparer: any CaptureInputPreparing = LocalCaptureInputPreparationService(),
        settingsOpener: any ApplicationSettingsOpening = SystemApplicationSettingsOpener(),
        voiceCapture: VoiceCaptureViewModel? = nil
    ) {
        self.captureService = captureService
        self.inputPreparer = inputPreparer
        self.settingsOpener = settingsOpener
        _voiceCapture = StateObject(wrappedValue: voiceCapture ?? VoiceCaptureViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Capture type") {
                    Picker("Type", selection: $kind) {
                        ForEach(CaptureKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                }

                if kind == .photo || kind == .screenshot {
                    Section(kind == .photo ? "Photo" : "Screenshot") {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose \(kind == .photo ? "Photo" : "Screenshot")", systemImage: "photo.on.rectangle")
                        }
                        Button("Attach Selected Image") {
                            Task { await loadSelectedPhoto() }
                        }
                        .disabled(selectedPhoto == nil)
                        AttachmentStatusRow(description: attachmentDescription)
                        TextField("Optional notes", text: $text, axis: .vertical)
                            .lineLimit(2...5)
                        CaptureTextLimitRow(textCount: text.count)
                    }
                } else if kind == .voice {
                    voiceSection
                } else {
                    Section(textPrompt) {
                        TextEditor(text: $text)
                            .frame(minHeight: 160)
                        CaptureTextLimitRow(textCount: text.count)
                    }
                }

                Section("Source") {
                    TextField("Optional label", text: $sourceLabel)
                    Text("\(sourceLabel.count)/\(CaptureInputLimits.maximumSourceLabelCharacters)")
                        .font(.caption)
                        .foregroundStyle(sourceLabel.count > CaptureInputLimits.maximumSourceLabelCharacters ? .red : .secondary)
                    Text(sourceHelp)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Capture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        voiceCapture.discardRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $showingAudioImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false,
                onCompletion: importAudio
            )
            .onChange(of: kind) { _, _ in
                attachment = nil
                attachmentDescription = ""
                selectedPhoto = nil
                voiceCapture.discardRecording()
            }
            .onDisappear { voiceCapture.discardRecording() }
        }
    }

    @ViewBuilder
    private var voiceSection: some View {
        Section("Voice") {
            voicePermissionControls

            if voiceCapture.state == .recording {
                Button("Stop Recording", systemImage: "stop.fill", action: stopVoiceRecording)
                Button("Cancel Recording", role: .destructive, action: voiceCapture.cancelActiveRecording)
            } else {
                Button("Start Recording", systemImage: "mic.fill", action: startVoiceRecording)
                    .disabled(!voiceCapture.permissionStatus.canRecord)
            }

            if let recording = voiceCapture.recording {
                Label(
                    "Recording ready (\(recording.duration.formatted(.number.precision(.fractionLength(1)))) seconds)",
                    systemImage: "waveform.badge.checkmark"
                )
                .foregroundStyle(.green)
                Button(voiceCapture.state == .playing ? "Stop Playback" : "Play Recording", systemImage: voiceCapture.state == .playing ? "stop.fill" : "play.fill") {
                    voiceCapture.togglePlayback()
                }
                Button("Transcribe on Device", systemImage: "text.quote") {
                    Task {
                        if let transcript = await voiceCapture.transcribe() {
                            appendTranscript(transcript)
                        }
                    }
                }
                .disabled(!voiceCapture.permissionStatus.canTranscribe)
                Button("Discard Recording", role: .destructive, action: voiceCapture.discardRecording)
            }

            Button("Choose Audio File", systemImage: "folder.badge.plus") {
                voiceCapture.discardRecording()
                showingAudioImporter = true
            }
            AttachmentStatusRow(description: attachmentDescription)
            TextField("Optional transcript or notes", text: $text, axis: .vertical)
                .lineLimit(2...5)
            CaptureTextLimitRow(textCount: text.count)

            if let voiceMessage = voiceCapture.message {
                Label(voiceMessage, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Recording is kept in a protected temporary file until it is encrypted into this capture or you discard it. Audio is limited to \(ByteCountFormatter.string(fromByteCount: Int64(CaptureInputLimits.maximumAudioBytes), countStyle: .file)); transcription stays on device when available, otherwise you can add text manually.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var voicePermissionControls: some View {
        let permission = voiceCapture.permissionStatus
        if permission.microphone == .notDetermined || permission.speechRecognition == .notDetermined {
            Button("Allow Microphone and Speech Recognition") {
                Task { await voiceCapture.requestPermissions() }
            }
        }
        if permission.microphone == .denied || permission.speechRecognition == .denied {
            Label("Microphone or speech access was denied", systemImage: "mic.slash")
                .foregroundStyle(.orange)
            Button("Open Settings", action: settingsOpener.openApplicationSettings)
        } else if permission.microphone == .restricted || permission.speechRecognition == .restricted {
            Label("Voice permissions are restricted on this device", systemImage: "mic.slash")
                .foregroundStyle(.secondary)
        } else if permission.microphone == .unavailable {
            Label("Microphone recording is unavailable", systemImage: "mic.slash")
                .foregroundStyle(.secondary)
        }
    }

    private var textPrompt: String {
        switch kind {
        case .email: return "Paste an email excerpt"
        case .sharedText: return "Paste shared text"
        case .text: return "Write or paste text"
        default: return "Notes"
        }
    }

    private var sourceHelp: String {
        switch kind {
        case .email:
            return "Manual email capture only. This app never connects to an inbox."
        case .sharedText:
            return "Use this for text shared into the app from another app."
        default:
            return "Give this capture a helpful local label if needed."
        }
    }

    private var canSave: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch kind {
        case .photo, .screenshot:
            return attachment != nil
        case .voice:
            return attachment != nil || voiceCapture.recording != nil
        case .text, .email, .sharedText:
            return hasText
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self), !data.isEmpty else {
                errorMessage = "The selected image could not be read."
                return
            }
            attachment = try inputPreparer.prepareImage(data: data, originalFilename: "selected-image")
            attachmentDescription = "Image prepared for encrypted storage"
            errorMessage = nil
        } catch let error as CaptureInputPreparationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "The selected image could not be imported."
        }
    }

    private func importAudio(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            attachment = try inputPreparer.prepareAudioFile(at: url)
            attachmentDescription = attachment?.originalFilename ?? "Audio selected"
            errorMessage = nil
        } catch let error as CaptureInputPreparationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "The audio file could not be imported."
        }
    }

    private func save() {
        do {
            let preparedAttachment = try attachmentForSaving()
            _ = try captureService.importCapture(
                kind: kind,
                text: try inputPreparer.normalizedText(text),
                attachment: preparedAttachment,
                sourceLabel: try inputPreparer.normalizedSourceLabel(sourceLabel),
                into: modelContext
            )
            voiceCapture.discardRecording()
            dismiss()
        } catch let error as CaptureInputPreparationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "This capture could not be saved securely. Check that the required content is selected and try again."
        }
    }

    private func startVoiceRecording() {
        attachment = nil
        attachmentDescription = ""
        voiceCapture.startRecording()
    }

    private func stopVoiceRecording() {
        voiceCapture.stopRecording()
        if voiceCapture.recording != nil {
            attachment = nil
            attachmentDescription = ""
        }
    }

    private func appendTranscript(_ transcript: String) {
        let current = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = current.isEmpty ? transcript : "\(current)\n\n\(transcript)"
    }

    private func attachmentForSaving() throws -> PreparedCaptureAttachment? {
        if let attachment { return attachment }
        guard kind == .voice, let recording = voiceCapture.recording else { return nil }
        return try inputPreparer.prepareAudioFile(at: recording.fileURL)
    }
}

private struct CaptureTextLimitRow: View {
    let textCount: Int

    var body: some View {
        Text("\(textCount)/\(CaptureInputLimits.maximumTextCharacters)")
            .font(.caption)
            .foregroundStyle(textCount > CaptureInputLimits.maximumTextCharacters ? .red : .secondary)
    }
}

private struct AttachmentStatusRow: View {
    let description: String

    var body: some View {
        if !description.isEmpty {
            Label(description, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("No attachment selected", systemImage: "paperclip")
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct CaptureDetailView: View {
    let capture: CaptureRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var environment: AppEnvironment
    private let captureServiceOverride: (any CaptureImporting)?
    @State private var decryptedText: String?
    @State private var attachmentData: Data?
    @State private var loadMessage: String?
    @State private var reviewDestination: CaptureReviewDestination?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    private var kind: CaptureKind? { CaptureKind(rawValue: capture.type) }

    init(capture: CaptureRecord, captureService: (any CaptureImporting)? = nil) {
        self.capture = capture
        captureServiceOverride = captureService
    }

    private var captureService: any CaptureImporting {
        captureServiceOverride ?? environment.captureService
    }

    private var reviewStatusLabel: String {
        switch capture.currentReviewState {
        case .pending: return capture.processed ? "Complete" : "Required"
        case .inProgress: return "In progress"
        case .completed: return "Complete"
        }
    }

    var body: some View {
        Form {
            Section("Capture") {
                LabeledContent("Type", value: kind?.displayName ?? capture.type.capitalized)
                LabeledContent("Created", value: capture.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let source = capture.sourceLabel, !source.isEmpty {
                    LabeledContent("Source", value: source)
                }
                HStack {
                    Text("Review")
                    Spacer()
                    Text(reviewStatusLabel)
                        .foregroundStyle(capture.processed ? .green : .orange)
                }
                if let byteCount = capture.attachmentByteCount {
                    LabeledContent(
                        "Encrypted attachment",
                        value: ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
                    )
                }
            }

            Section("Encrypted content") {
                if let text = decryptedText, !text.isEmpty {
                    Text(text)
                        .textSelection(.enabled)
                } else if let attachmentData, let image = UIImage(data: attachmentData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                } else if attachmentData != nil {
                    Label("Encrypted attachment available", systemImage: "paperclip")
                } else if let loadMessage {
                    Text(loadMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView("Opening encrypted content…")
                }
            }

            Section("Review") {
                NavigationLink {
                    AIExtractionReviewView(capture: capture)
                } label: {
                    Label("Review AI Suggestions", systemImage: "sparkles")
                }
                if capture.processed {
                    Label("This capture has been reviewed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Confirm only the facts you want to keep. AI review remains unavailable until Account & AI is configured.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Create Person", systemImage: "person.badge.plus") { reviewDestination = .person }
                    Button("Create Memory", systemImage: "brain.head.profile") { reviewDestination = .memory }
                    Button("Create Reminder", systemImage: "checklist") { reviewDestination = .reminder }
                    Button("Create Event", systemImage: "calendar.badge.plus") { reviewDestination = .event }
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Review Capture")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog("Delete this capture?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Encrypted Capture", role: .destructive, action: deleteCapture)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its encrypted text and attachment will be removed from this device.")
        }
        .sheet(item: $reviewDestination) { destination in
            reviewSheet(for: destination)
        }
        .task { loadContent() }
    }

    @ViewBuilder
    private func reviewSheet(for destination: CaptureReviewDestination) -> some View {
        switch destination {
        case .person:
            PersonEditorView(person: nil, sourceCapture: capture, prefillText: decryptedText)
        case .memory:
            MemoryEditorView(memory: nil, sourceCapture: capture, prefillText: decryptedText)
        case .reminder:
            ReminderEditorView(reminder: nil, sourceCapture: capture, prefillText: decryptedText)
        case .event:
            SocialEventEditorView(event: nil, sourceCapture: capture, prefillText: decryptedText)
        }
    }

    private func loadContent() {
        do {
            decryptedText = try captureService.decryptedText(for: capture)
            attachmentData = try captureService.decryptedAttachment(for: capture)
            if decryptedText == nil && attachmentData == nil {
                if !capture.rawContent.isEmpty {
                    // Only for records created by the pre-encryption migration path.
                    decryptedText = capture.rawContent
                } else {
                    loadMessage = "This capture has no readable local payload."
                }
            }
        } catch {
            loadMessage = "This encrypted content could not be opened on this device."
        }
    }

    private func deleteCapture() {
        do {
            try captureService.deleteCapture(capture, from: modelContext)
            dismiss()
        } catch {
            errorMessage = "This capture could not be deleted completely."
        }
    }
}
