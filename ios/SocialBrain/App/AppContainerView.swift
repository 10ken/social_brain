import SwiftUI

private enum AppTab: Hashable {
    case home
    case calendar
    case capture
    case communities
    case recall
}

/// The app is deliberately local-first. Cloud sync is not exposed here because
/// the current encryption key is device-bound and cannot safely be recovered on
/// a second device.
@MainActor
struct AppContainerView: View {
    @State private var selectedTab: AppTab = .home
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var persistenceFailures = LocalPersistenceFailureReporter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeWorkspaceView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
                .accessibilityIdentifier("tab.home")

            CalendarWorkspaceView(calendarService: environment.calendarService)
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)
                .accessibilityIdentifier("tab.calendar")

            CaptureWorkspaceView(
                captureService: environment.captureService,
                voiceCaptureService: environment.voiceCaptureService,
                contactService: environment.contactImportService
            )
                .tabItem { Label("Capture", systemImage: "plus.circle.fill") }
                .tag(AppTab.capture)
                .accessibilityIdentifier("tab.capture")

            CommunitiesWorkspaceView()
                .tabItem { Label("Communities", systemImage: "person.2") }
                .tag(AppTab.communities)
                .accessibilityIdentifier("tab.communities")

            RecallWorkspaceView()
                .tabItem { Label("Recall", systemImage: "magnifyingglass") }
                .tag(AppTab.recall)
                .accessibilityIdentifier("tab.recall")
        }
        .tint(.teal)
        .task {
            // Firebase configuration is installed by the application delegate.
            // Refresh after the root has appeared so a Firebase Debug launch
            // does not remain in its initial pre-configuration state.
            await environment.refreshProtectedServices()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await environment.refreshProtectedServices() }
        }
        .alert(
            "Local changes need attention",
            isPresented: Binding(
                get: { persistenceFailures.message != nil },
                set: { if !$0 { persistenceFailures.clearMessage() } }
            )
        ) {
            Button("OK", role: .cancel) { persistenceFailures.clearMessage() }
        } message: {
            Text(persistenceFailures.message ?? "Changes could not be saved locally.")
        }
    }
}
