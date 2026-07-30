import Foundation
import SwiftData
import XCTest
@testable import SocialBrain

@MainActor
final class ExtractionReviewServiceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testSuggestionDecisionIsEncryptedAndCaptureCompletesOnlyAfterResolution() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = LocalEncryptedContentStore(
            keyProvider: InMemoryContentKeyProvider(),
            directoryURL: temporaryDirectory
        )
        let capture = try LocalCaptureService(contentStore: store).importCapture(
            CaptureImportRequest(kind: .text, text: "Michelle is a friend."),
            into: context
        )
        let extraction = try AIExtractionResult.decodeStrict(from: """
        {"people":[{"name":"Michelle","confidenceState":"suggested","evidence":"Michelle is named in the capture."}],"events":[],"memories":[],"relationships":[],"reminders":[]}
        """)
        let reviews = ExtractionReviewService(contentStore: store)

        let pending = try reviews.start(result: extraction, for: capture, in: context)
        XCTAssertFalse(capture.processed)
        XCTAssertEqual(capture.reviewSuggestionCount, 1)
        XCTAssertNotNil(capture.encryptedReviewReference)

        let confirmed = try reviews.confirm(
            suggestionID: try XCTUnwrap(pending.suggestions.first?.id),
            title: "Michelle",
            detail: nil,
            in: pending,
            for: capture,
            in: context
        )

        XCTAssertEqual(confirmed.resolvedCount, 1)
        XCTAssertTrue(capture.processed)
        XCTAssertEqual(capture.currentReviewState, .completed)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PersonRecord>()).map(\.fullName), ["Michelle"])
        XCTAssertEqual(try reviews.load(for: capture), confirmed)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            PersonRecord.self, GroupRecord.self, GroupMembershipRecord.self,
            RelationshipRecord.self, SocialEventRecord.self, EventAttendeeRecord.self,
            MemoryRecord.self, CaptureRecord.self, ReminderRecord.self, AppSettingsRecord.self
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
