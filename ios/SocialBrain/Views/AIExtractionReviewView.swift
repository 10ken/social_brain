import SwiftData
import SwiftUI

/// Encrypted, per-suggestion review. No structured record is created until an
/// individual suggestion is explicitly confirmed in this screen.
@MainActor
struct AIExtractionReviewView: View {
    let capture: CaptureRecord

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var environment: AppEnvironment
    private let reviewService: ExtractionReviewService
    @State private var review: StoredExtractionReview?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingFinishConfirmation = false

    init(capture: CaptureRecord, reviewService: ExtractionReviewService = ExtractionReviewService()) {
        self.capture = capture
        self.reviewService = reviewService
    }

    private var availability: ProtectedFeatureAvailability {
        ProtectedFeatureAvailability.aiAccess(
            authentication: environment.authentication.state,
            appCheck: environment.appCheck.state
        )
    }

    var body: some View {
        List {
            Section("Review status") {
                if let review {
                    LabeledContent("Suggestions", value: "\(review.resolvedCount) of \(review.suggestions.count) resolved")
                    Text(review.isComplete ? "Review complete" : "Every suggestion needs a decision, or choose Finish Review when you are done.")
                        .font(.footnote)
                        .foregroundStyle(review.isComplete ? .green : .secondary)
                } else {
                    Text("Generate suggestions only after you are ready to review them. Manual record creation remains available without AI.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if review == nil {
                generationSection
            } else if let review {
                ForEach(review.suggestions) { suggestion in
                    Section(suggestion.kind.rawValue.capitalized) {
                        ExtractionSuggestionCard(
                            suggestion: suggestion,
                            confirm: { title, detail in confirm(suggestion.id, title: title, detail: detail) },
                            reject: { reject(suggestion.id) }
                        )
                    }
                }

                if !review.isComplete {
                    Section {
                        Button("Finish Review", role: .destructive) {
                            showingFinishConfirmation = true
                        }
                    } footer: {
                        Text("This marks unresolved suggestions as deliberately left for later. It does not create records for them.")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("AI Suggestion Review")
        .task { loadReview() }
        .confirmationDialog("Finish review?", isPresented: $showingFinishConfirmation, titleVisibility: .visible) {
            Button("Finish Review", role: .destructive, action: finishReview)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unresolved suggestions will not create records. You can run a new AI review later.")
        }
    }

    @ViewBuilder
    private var generationSection: some View {
        Section("AI suggestions") {
            switch availability {
            case .available:
                Button(isGenerating ? "Generating Suggestions…" : "Generate AI Suggestions", systemImage: "sparkles") {
                    generateSuggestions()
                }
                .disabled(isGenerating)
                .accessibilityIdentifier("capture.ai.generate")
            case .unavailable(let reason):
                Label("AI suggestions unavailable", systemImage: "lock.trianglebadge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadReview() {
        do {
            review = try reviewService.load(for: capture)
        } catch {
            errorMessage = "This encrypted review could not be opened on this device."
        }
    }

    private func generateSuggestions() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let text = try environment.captureService.decryptedText(for: capture)
                let attachment = try environment.captureService.decryptedAttachment(for: capture)
                let image: AIImagePayload?
                if let attachment,
                   let mimeType = capture.attachmentMIMEType,
                   mimeType.hasPrefix("image/") {
                    image = try AIImagePayload(mimeType: mimeType, data: attachment)
                } else {
                    image = nil
                }
                let prompt = extractionPrompt(for: text)
                let request = try AIExtractionRequest(
                    prompt: prompt,
                    systemInstruction: extractionSystemInstruction,
                    responseMimeType: .json,
                    image: image
                )
                let result = try await environment.aiGateway.extract(request)
                review = try reviewService.start(result: result, for: capture, in: modelContext)
            } catch let error as AIClientError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "AI suggestions could not be prepared from this capture."
            }
            isGenerating = false
        }
    }

    private func confirm(_ id: UUID, title: String, detail: String?) {
        guard let review else { return }
        do {
            self.review = try reviewService.confirm(
                suggestionID: id,
                title: title,
                detail: detail,
                in: review,
                for: capture,
                in: modelContext
            )
            errorMessage = nil
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "This suggestion could not be confirmed."
        } catch {
            errorMessage = "This suggestion could not be confirmed."
        }
    }

    private func reject(_ id: UUID) {
        guard let review else { return }
        do {
            self.review = try reviewService.reject(
                suggestionID: id,
                in: review,
                for: capture,
                in: modelContext
            )
            errorMessage = nil
        } catch {
            errorMessage = "This suggestion could not be rejected."
        }
    }

    private func finishReview() {
        guard let review else { return }
        do {
            self.review = try reviewService.finish(review: review, for: capture, in: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = "This review could not be finished."
        }
    }

    private func extractionPrompt(for text: String?) -> String {
        let content = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let content, !content.isEmpty {
            return "Extract only the reviewable social facts from this user-selected capture:\n\n\(content)"
        }
        return "Extract only the reviewable social facts visible in this user-selected image."
    }

    private var extractionSystemInstruction: String {
        "Return only JSON matching the Social Brain extraction contract with camelCase fields: people, events, memories, relationships, and reminders. Include evidence for every suggestion. Do not invent facts."
    }
}

private struct ExtractionSuggestionCard: View {
    let suggestion: StoredExtractionSuggestion
    let confirm: (String, String?) -> Void
    let reject: () -> Void

    @State private var title: String
    @State private var detail: String

    init(
        suggestion: StoredExtractionSuggestion,
        confirm: @escaping (String, String?) -> Void,
        reject: @escaping () -> Void
    ) {
        self.suggestion = suggestion
        self.confirm = confirm
        self.reject = reject
        _title = State(initialValue: suggestion.title)
        _detail = State(initialValue: suggestion.detail ?? "")
    }

    var body: some View {
        TextField("Suggestion", text: $title, axis: .vertical)
            .lineLimit(1...4)
            .disabled(suggestion.decision.isResolved)
        if suggestion.detail != nil {
            TextField("Details", text: $detail, axis: .vertical)
                .lineLimit(1...3)
                .disabled(suggestion.decision.isResolved)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Evidence")
                .font(.caption.weight(.semibold))
            Text(suggestion.evidence)
                .font(.footnote)
                .textSelection(.enabled)
        }
        if suggestion.decision.isResolved {
            Label(decisionLabel, systemImage: suggestion.decision == .rejected ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(suggestion.decision == .rejected ? .secondary : .green)
        } else {
            HStack {
                Button("Confirm") { confirm(title, detail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty) }
                    .buttonStyle(.borderedProminent)
                Button("Reject", role: .destructive, action: reject)
                    .buttonStyle(.bordered)
            }
            .accessibilityIdentifier("capture.review.\(suggestion.id.uuidString)")
        }
    }

    private var decisionLabel: String {
        switch suggestion.decision {
        case .confirmed: return "Confirmed"
        case .edited: return "Confirmed with edits"
        case .rejected: return "Rejected"
        case .pending: return "Pending"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
