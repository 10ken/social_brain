import AuthenticationServices
import SwiftData
import SwiftUI
import UIKit

extension SyncableRecord {
    var isVisibleInDefaultLists: Bool {
        archivedAt == nil && deletedAt == nil
    }

    func markUpdated() {
        updatedAt = .now
    }
}

@MainActor
@discardableResult
func saveLocalChanges(_ context: ModelContext) -> Bool {
    LocalPersistenceFailureReporter.shared.save(context)
}

struct RecordLifecycleActions: View {
    let isArchived: Bool
    let archive: () -> Void
    let restore: () -> Void
    let delete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        Menu {
            Button(isArchived ? "Restore" : "Archive", systemImage: isArchived ? "tray.and.arrow.up" : "archivebox") {
                isArchived ? restore() : archive()
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .confirmationDialog(
            "Delete this record?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be removed from your local lists. Start Clean permanently erases all local content.")
        }
    }
}

struct EvidenceSection: View {
    let evidenceText: String?
    let sourceID: UUID?

    @Query(sort: \CaptureRecord.createdAt, order: .reverse) private var captures: [CaptureRecord]

    private var sourceCapture: CaptureRecord? {
        guard let sourceID else { return nil }
        return captures.first { $0.id == sourceID }
    }

    var body: some View {
        if let evidence = evidenceText?.trimmingCharacters(in: .whitespacesAndNewlines), !evidence.isEmpty {
            Section("Evidence") {
                Text(evidence)
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }

        if let sourceCapture {
            Section("Source") {
                NavigationLink {
                    CaptureDetailView(capture: sourceCapture)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sourceCapture.type.capitalized + " capture")
                        Text(sourceCapture.createdAt, style: .date)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct ConfidenceBadge: View {
    let state: String

    private var label: String {
        switch state.lowercased() {
        case "confirmed": return "Confirmed"
        case "needs_review": return "Needs review"
        default: return "Suggested"
        }
    }

    private var color: Color {
        switch state.lowercased() {
        case "confirmed": return .green
        case "needs_review": return .orange
        default: return .blue
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct CloudSyncUnavailableSection: View {
    var body: some View {
        Section("Sync") {
            Label("Cloud sync is unavailable", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
            Text("This build keeps imported capture payloads encrypted on this device. Cross-device sync stays off until a cross-platform recovery-key design is approved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct AuthenticationAndAIStatusView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var appleNonce = ""

    private var authentication: AuthenticationStateStore { environment.authentication }
    private var appCheck: AppCheckStateStore { environment.appCheck }

    private var aiAvailability: ProtectedFeatureAvailability {
        ProtectedFeatureAvailability.aiAccess(
            authentication: authentication.state,
            appCheck: appCheck.state
        )
    }

    var body: some View {
        List {
            Section {
                authenticationStatus
                Text("Local capture, planning, and recall remain available without an account.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Account")
            }

            accountActions

            Section("AI suggestions") {
                aiAvailabilityRow
                Text("Sign in and Firebase App Check are required before content can be sent to the protected AI service. Nothing is sent while this screen shows unavailable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Check App Check") {
                    Task { await appCheck.refresh() }
                }
            }

            CloudSyncUnavailableSection()
        }
        .navigationTitle("Account & AI")
    }

    @ViewBuilder
    private var authenticationStatus: some View {
        switch authentication.state {
        case .unavailable(let message):
            Label("Account setup unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary)
        case .signedOut:
            Label("You are signed out", systemImage: "person.crop.circle.badge.questionmark")
                .font(.headline)
        case .signingIn(let provider):
            Label("Signing in with \(provider.rawValue.capitalized)…", systemImage: "person.crop.circle.badge.clock")
                .font(.headline)
        case .signedIn(let userID):
            Label("Signed in", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
            Text("Account: \(userID)").font(.footnote).foregroundStyle(.secondary)
        case .failed(let message):
            Label("Sign-in needs attention", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.headline)
            Text(message).font(.footnote).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var accountActions: some View {
        Section("Sign in") {
            if authentication.state.userID != nil {
                Button("Sign Out", role: .destructive) { authentication.signOut() }
                NavigationLink {
                    AccountDeletionView()
                } label: {
                    Label("Delete Firebase Account…", systemImage: "person.crop.circle.badge.minus")
                        .foregroundStyle(.red)
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    appleNonce = AuthenticationStateStore.makeAppleNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AuthenticationStateStore.sha256(appleNonce)
                } onCompletion: { result in
                    switch result {
                    case let .success(authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let token = credential.identityToken
                        else {
                            authentication.reportAppleTokenFailure()
                            return
                        }
                        Task { await authentication.signInWithApple(identityToken: token, rawNonce: appleNonce) }
                    case let .failure(error):
                        authentication.handleAppleAuthorizationFailure(error)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)

                Button("Continue with Google", systemImage: "g.circle") {
                    guard let controller = topViewController() else { return }
                    Task { await authentication.signInWithGoogle(presenting: controller) }
                }
                .accessibilityIdentifier("auth.google")
            }
        }
    }

    @ViewBuilder
    private var aiAvailabilityRow: some View {
        switch aiAvailability {
        case .available:
            Label("AI suggestions are ready", systemImage: "checkmark.shield.fill")
                .foregroundStyle(.green)
        case .unavailable(let reason):
            Label("AI suggestions unavailable", systemImage: "lock.trianglebadge.exclamationmark")
                .foregroundStyle(.secondary)
            Text(reason).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func topViewController(from controller: UIViewController? = nil) -> UIViewController? {
        let root = controller ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first?.rootViewController
        if let navigation = root as? UINavigationController { return topViewController(from: navigation.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(from: tab.selectedViewController) }
        if let presented = root?.presentedViewController { return topViewController(from: presented) }
        return root
    }
}

@MainActor
private struct AccountDeletionView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var confirmation = ""
    @State private var showingConfirmation = false
    @State private var isDeleting = false
    @State private var status: String?

    var body: some View {
        List {
            Section("What this deletes") {
                Text("This removes the Firebase account and server-side account data. It does not erase this device automatically; use Start Clean separately if you want to erase local encrypted content.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Delete Firebase Account…", role: .destructive) {
                    confirmation = ""
                    showingConfirmation = true
                }
                .disabled(isDeleting)
            }
            if let status {
                Section {
                    Label(status, systemImage: status.contains("deleted") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(status.contains("deleted") ? .green : .red)
                }
            }
        }
        .navigationTitle("Delete Account")
        .alert("Delete Firebase account?", isPresented: $showingConfirmation) {
            TextField("Type DELETE ACCOUNT", text: $confirmation)
                .textInputAutocapitalization(.characters)
            Button("Delete Account", role: .destructive) { deleteAccount() }
                .disabled(confirmation.uppercased() != "DELETE ACCOUNT")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You may need to sign in again first because account deletion requires recent authentication.")
        }
    }

    private func deleteAccount() {
        isDeleting = true
        status = nil
        Task {
            do {
                try await environment.aiGateway.deleteAccountData()
                status = "Firebase account deleted. Use Start Clean separately to erase this device."
            } catch let error as AIClientError {
                status = error.localizedDescription
            } catch {
                status = "Account deletion could not be completed. Please try again."
            }
            isDeleting = false
        }
    }
}

struct PrivacyPermissionsView: View {
    var body: some View {
        List {
            Section {
                PermissionRationaleRow(
                    icon: "calendar",
                    title: "Calendar",
                    detail: "Used only when you choose to import events or write a confirmed event to a device calendar."
                )
                PermissionRationaleRow(
                    icon: "person.crop.circle",
                    title: "Contacts",
                    detail: "Used only when you choose people to import. Contacts are not automatically uploaded."
                )
                PermissionRationaleRow(
                    icon: "photo.on.rectangle",
                    title: "Photos",
                    detail: "Used only for a screenshot or photo you select to review locally."
                )
                PermissionRationaleRow(
                    icon: "mic",
                    title: "Microphone and Speech Recognition",
                    detail: "Used only while you record and transcribe a voice capture."
                )
            } header: {
                Text("Why permissions are requested")
            } footer: {
                Text("Each permission is requested at the moment you use its feature. You can revoke access in iOS Settings at any time.")
            }

            Section("Privacy") {
                Label("Captured content stays local by default", systemImage: "lock.fill")
                Label("Manual email capture only", systemImage: "envelope.badge")
                Text("The app never connects to an inbox. Paste or share an email excerpt for review instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy & Permissions")
    }
}

private struct PermissionRationaleRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
        }
        .padding(.vertical, 2)
    }
}

@MainActor
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    private let resetService = LocalDataResetService()
    @State private var confirmationText = ""
    @State private var isShowingConfirmation = false
    @State private var status: LocalResetStatus?

    private let confirmationPhrase = "START CLEAN"

    var body: some View {
        List {
            Section("Local data") {
                Label("All current records are stored locally", systemImage: "internaldrive")
                Text("Deleted records are hidden from normal lists. Start Clean removes all saved local records from this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            CloudSyncUnavailableSection()

            Section("Start clean") {
                Text("This permanently removes people, groups, relationships, events, memories, reminders, and reviewed captures from the local store.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Start Clean…", role: .destructive) {
                    confirmationText = ""
                    isShowingConfirmation = true
                }
            }

            if let status {
                Section {
                    Label(status.message, systemImage: status.isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(status.isFailure ? .red : .green)
                }
            }
        }
        .navigationTitle("Data Management")
        .alert("Start clean?", isPresented: $isShowingConfirmation) {
            TextField("Type START CLEAN", text: $confirmationText)
                .textInputAutocapitalization(.characters)
            Button("Erase Local Data", role: .destructive) {
                eraseLocalData()
            }
            .disabled(confirmationText.uppercased() != confirmationPhrase)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Type START CLEAN to continue.")
        }
    }

    private func eraseLocalData() {
        do {
            try resetService.wipeAllLocalContent(in: modelContext)
            status = .success("Local records erased.")
        } catch let error as LocalDataResetError {
            status = .failure(error.localizedDescription)
        } catch {
            status = .failure("Could not erase all local records. Try again.")
        }
    }
}

private enum LocalResetStatus {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let message), .failure(let message): return message
        }
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

struct SettingsView: View {
    var body: some View {
        List {
            Section("Security") {
                NavigationLink {
                    AuthenticationAndAIStatusView()
                } label: {
                    Label("Account & AI", systemImage: "person.badge.key")
                }
                NavigationLink {
                    PrivacyPermissionsView()
                } label: {
                    Label("Privacy & Permissions", systemImage: "hand.raised")
                }
            }

            Section("Data") {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Label("Data Management", systemImage: "externaldrive")
                }
                NavigationLink {
                    ArchivedRecordsView()
                } label: {
                    Label("Archived Records", systemImage: "archivebox")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
