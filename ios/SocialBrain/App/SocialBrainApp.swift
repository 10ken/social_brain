import SwiftData
import SwiftUI

@main
struct SocialBrainApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseAppDelegate
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            PersonRecord.self, GroupRecord.self, GroupMembershipRecord.self,
            RelationshipRecord.self, SocialEventRecord.self, EventAttendeeRecord.self,
            MemoryRecord.self, CaptureRecord.self, ReminderRecord.self, AppSettingsRecord.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Unable to create the Social Brain local store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppContainerView()
        }
        .modelContainer(modelContainer)
    }
}
