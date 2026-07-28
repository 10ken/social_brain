import Foundation
import SwiftData
import XCTest
@testable import SocialBrain

@MainActor
final class LocalCaptureAndResetTests: XCTestCase {
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

    func testImportedTextIsEncryptedAndRemainsReviewRequired() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let captures = LocalCaptureService(contentStore: store)

        let capture = try captures.importCapture(
            CaptureImportRequest(kind: .email, text: "Meet Alex on Friday", sourceLabel: "Pasted email"),
            into: context
        )

        XCTAssertEqual(capture.rawContent, "")
        XCTAssertFalse(capture.processed)
        XCTAssertEqual(capture.contentPreview, "Email capture")
        XCTAssertNotNil(capture.encryptedContentReference)
        XCTAssertEqual(try captures.decryptedText(for: capture), "Meet Alex on Friday")

        try captures.saveAnalysis(Data("{\"memories\":[]}".utf8), for: capture, in: context)
        XCTAssertEqual(try captures.decryptedAnalysis(for: capture), Data("{\"memories\":[]}".utf8))
        XCTAssertFalse(capture.processed)
    }

    func testPhotoCaptureRequiresAttachment() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let captures = LocalCaptureService(
            contentStore: LocalEncryptedContentStore(
                keyProvider: InMemoryContentKeyProvider(),
                directoryURL: temporaryDirectory
            )
        )

        XCTAssertThrowsError(
            try captures.importCapture(CaptureImportRequest(kind: .photo, text: "description only"), into: context)
        ) { error in
            XCTAssertEqual(error as? CaptureImportError, .attachmentRequired)
        }
    }

    func testImportedAttachmentIsEncrypted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = LocalEncryptedContentStore(
            keyProvider: InMemoryContentKeyProvider(),
            directoryURL: temporaryDirectory
        )
        let captures = LocalCaptureService(contentStore: store)
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])

        let capture = try captures.importCapture(
            CaptureImportRequest(
                kind: .screenshot,
                attachment: CaptureAttachment(data: imageBytes, fileExtension: "png", mimeType: "image/png")
            ),
            into: context
        )

        XCTAssertNotNil(capture.encryptedAttachmentReference)
        XCTAssertEqual(try captures.decryptedAttachment(for: capture), imageBytes)
        XCTAssertEqual(capture.rawContent, "")
    }

    func testStartCleanDeletesSwiftDataRecordsAndDestroysDeviceKey() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let captures = LocalCaptureService(contentStore: store)
        context.insert(PersonRecord(fullName: "Alex"))
        _ = try captures.importCapture(CaptureImportRequest(kind: .text, text: "Private note"), into: context)
        try context.save()

        try LocalDataResetService(encryptedContentStore: store).wipeAllLocalContent(in: context)

        XCTAssertFalse(keys.hasKey)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PersonRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CaptureRecord>()).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.path))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            PersonRecord.self, GroupRecord.self, GroupMembershipRecord.self,
            RelationshipRecord.self, SocialEventRecord.self, EventAttendeeRecord.self,
            MemoryRecord.self, CaptureRecord.self, ReminderRecord.self, AppSettingsRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
