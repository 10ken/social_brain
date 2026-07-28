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
    @State private var showingComposer = false

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
                            CaptureDetailView(capture: capture)
                        } label: {
                            CaptureRow(capture: capture)
                        }
                    }
                }
            }
            .navigationTitle("Capture")
            .toolbar {
                Button("Add", systemImage: "plus") { showingComposer = true }
            }
            .sheet(isPresented: $showingComposer) {
                CaptureComposerView()
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
        case .photo: "photo"
        case .screenshot: "rectangle.on.rectangle"
        case .voice: "waveform"
        case .email: "envelope"
        case .sharedText: "square.and.arrow.down"
        case .text, .none: "text.alignleft"
        }
    }
}

@MainActor
struct CaptureComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    private let captureService: any CaptureImporting = LocalCaptureService()

    @State private var kind: CaptureKind = .text
    @State private var text = ""
    @State private var sourceLabel = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachment: CaptureAttachment?
    @State private var attachmentDescription = ""
    @State private var showingAudioImporter = false
    @State private var errorMessage: String?

    private var requiresAttachment: Bool {
        switch kind {
        case .photo, .screenshot, .voice: true
        case .text, .email, .sharedText: false
        }
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
                    }
                } else if kind == .voice {
                    Section("Voice") {
                        Button("Choose Audio File", systemImage: "waveform") {
                            showingAudioImporter = true
                        }
                        AttachmentStatusRow(description: attachmentDescription)
                        TextField("Optional transcript or notes", text: $text, axis: .vertical)
                            .lineLimit(2...5)
                        Text("The selected audio stays encrypted on this device and requires review. Recording and speech transcription permissions are requested only when those controls are enabled in a production build.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(textPrompt) {
                        TextEditor(text: $text)
                            .frame(minHeight: 160)
                    }
                }

                Section("Source") {
                    TextField("Optional label", text: $sourceLabel)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
            }
        }
    }

    private var textPrompt: String {
        switch kind {
        case .email: "Paste an email excerpt"
        case .sharedText: "Paste shared text"
        case .text: "Write or paste text"
        default: "Notes"
        }
    }

    private var sourceHelp: String {
        switch kind {
        case .email:
            "Manual email capture only. This app never connects to an inbox."
        case .sharedText:
            "Use this for text shared into the app from another app."
        default:
            "Give this capture a helpful local label if needed."
        }
    }

    private var canSave: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return requiresAttachment ? attachment != nil : hasText
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self), !data.isEmpty else {
                errorMessage = "The selected image could not be read."
                return
            }
            attachment = CaptureAttachment(data: data, fileExtension: "image", mimeType: "image/*")
            attachmentDescription = "Image selected"
            errorMessage = nil
        } catch {
            errorMessage = "The selected image could not be imported."
        }
    }

    private func importAudio(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                errorMessage = "The audio file is empty."
                return
            }
            let type = UTType(filenameExtension: url.pathExtension)
            attachment = CaptureAttachment(
                data: data,
                fileExtension: url.pathExtension.isEmpty ? "audio" : url.pathExtension,
                mimeType: type?.preferredMIMEType ?? "audio/*"
            )
            attachmentDescription = url.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = "The audio file could not be imported."
        }
    }

    private func save() {
        do {
            _ = try captureService.importCapture(
                CaptureImportRequest(
                    kind: kind,
                    text: optional(text),
                    attachment: attachment,
                    sourceLabel: optional(sourceLabel)
                ),
                into: modelContext
            )
            dismiss()
        } catch {
            errorMessage = "This capture could not be saved securely. Check that the required content is selected and try again."
        }
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
    private let captureService: any CaptureImporting = LocalCaptureService()
    @State private var decryptedText: String?
    @State private var attachmentData: Data?
    @State private var loadMessage: String?
    @State private var reviewDestination: CaptureReviewDestination?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    private var kind: CaptureKind? { CaptureKind(rawValue: capture.type) }

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
                    Text(capture.processed ? "Complete" : "Required")
                        .foregroundStyle(capture.processed ? .green : .orange)
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
