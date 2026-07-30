import SwiftData
import SwiftUI

@main
@MainActor
struct SocialBrainApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseAppDelegate
    @StateObject private var environment: AppEnvironment

    init() {
        _environment = StateObject(wrappedValue: AppEnvironment.makeForCurrentRuntime())
    }

    var body: some Scene {
        WindowGroup {
            SocialBrainStorageRootView()
                .environmentObject(environment)
        }
    }
}

@MainActor
private struct SocialBrainStorageRootView: View {
    @State private var modelContainer: ModelContainer?
    @State private var storageErrorMessage: String?
    @State private var didRunLegacyMigration = false

    var body: some View {
        Group {
            if let modelContainer {
                AppContainerView()
                    .modelContainer(modelContainer)
                    .task {
                        guard !didRunLegacyMigration else { return }
                        didRunLegacyMigration = true
                        _ = LegacyCaptureMigrationService().migrateIfNeeded(in: ModelContext(modelContainer))
                    }
            } else {
                StorageRecoveryView(
                    message: storageErrorMessage,
                    retry: bootstrap,
                    startClean: cleanAndBootstrap
                )
            }
        }
        .task {
            guard modelContainer == nil else { return }
            bootstrap()
        }
    }

    private func bootstrap() {
        do {
            modelContainer = try SocialBrainModelContainerFactory.make()
            storageErrorMessage = nil
        } catch {
            // A malformed or unavailable local store is recoverable. Avoid
            // exposing filesystem/database details in a user-facing message.
            modelContainer = nil
            storageErrorMessage = "Social Brain could not open its local store on this device."
        }
    }

    private func cleanAndBootstrap() {
        // A container may be unavailable because of a transient condition. Try
        // once more before offering a destructive reset; if it still cannot be
        // opened, encrypted payload cleanup remains safe but SwiftData cannot
        // truthfully be reported as erased.
        let resetService = LocalDataResetService()
        do {
            let container = try SocialBrainModelContainerFactory.make()
            let context = ModelContext(container)
            try resetService.wipeAllLocalContent(in: context)
            modelContainer = container
            storageErrorMessage = nil
        } catch let error as LocalDataResetError {
            storageErrorMessage = error.localizedDescription
        } catch {
            // The database could not be opened, but encryption cleanup is
            // independent and must still be attempted. It reports SwiftData
            // as an honest partial failure because records could not be read.
            do {
                try resetService.wipeAllLocalContent(in: nil)
                storageErrorMessage = "Encrypted files were erased, but local records could not be opened for verification. Try again after freeing storage."
            } catch let resetError as LocalDataResetError {
                storageErrorMessage = resetError.localizedDescription
            } catch {
                storageErrorMessage = "The local store still could not be reset. Close the app, free device storage if needed, and try again."
            }
        }
    }
}

private struct StorageRecoveryView: View {
    let message: String?
    let retry: () -> Void
    let startClean: () -> Void

    @State private var confirmation = ""
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Local storage needs attention")
                .font(.title2.bold())
            Text(message ?? "Opening local storage…")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
            Button("Start Clean…", role: .destructive) {
                confirmation = ""
                showingConfirmation = true
            }
            Text("Start Clean is destructive and only proceeds after a typed confirmation.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .alert("Erase local data?", isPresented: $showingConfirmation) {
            TextField("Type START CLEAN", text: $confirmation)
                .textInputAutocapitalization(.characters)
            Button("Erase Local Data", role: .destructive, action: startClean)
                .disabled(confirmation.uppercased() != "START CLEAN")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes local records and encrypted capture content when the store can be opened.")
        }
    }
}
