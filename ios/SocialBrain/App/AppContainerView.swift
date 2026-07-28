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
struct AppContainerView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeWorkspaceView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            CalendarWorkspaceView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)

            CaptureWorkspaceView()
                .tabItem { Label("Capture", systemImage: "plus.circle.fill") }
                .tag(AppTab.capture)

            CommunitiesWorkspaceView()
                .tabItem { Label("Communities", systemImage: "person.2") }
                .tag(AppTab.communities)

            RecallWorkspaceView()
                .tabItem { Label("Recall", systemImage: "magnifyingglass") }
                .tag(AppTab.recall)
        }
        .tint(.teal)
    }
}
