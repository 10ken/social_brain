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

        let firstAnalysisReference = try XCTUnwrap(capture.encryptedAnalysisReference)
        try captures.saveAnalysis(Data("{\"memories\":[{\"content\":\"updated\"}]}".utf8), for: capture, in: context)
        XCTAssertNotEqual(capture.encryptedAnalysisReference, firstAnalysisReference)
        XCTAssertEqual(
            try captures.decryptedAnalysis(for: capture),
            Data("{\"memories\":[{\"content\":\"updated\"}]}".utf8)
        )
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
        let metadata = try captures.decryptedAttachmentMetadata(for: capture)
        XCTAssertEqual(metadata?.mimeType, "image/png")
        XCTAssertEqual(metadata?.fileExtension, "png")
        XCTAssertEqual(metadata?.byteCount, imageBytes.count)
        XCTAssertEqual(capture.rawContent, "")
    }

    func testLegacyPlaintextCaptureMigratesOnlyAfterEncryptedPayloadIsVerified() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let keys = InMemoryContentKeyProvider()
        let store = LocalEncryptedContentStore(keyProvider: keys, directoryURL: temporaryDirectory)
        let legacy = CaptureRecord(type: CaptureKind.text.rawValue, rawContent: "A legacy private note")
        legacy.analyzedJSON = "{\"people\":[]}"
        context.insert(legacy)
        try context.save()

        let result = LegacyCaptureMigrationService(contentStore: store).migrateIfNeeded(in: context)

        XCTAssertEqual(result.migratedCount, 1)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertEqual(legacy.rawContent, "")
        XCTAssertNil(legacy.analyzedJSON)
        XCTAssertNotNil(legacy.encryptedContentReference)
        XCTAssertNotNil(legacy.encryptedAnalysisReference)
        XCTAssertEqual(try LocalCaptureService(contentStore: store).decryptedText(for: legacy), "A legacy private note")
    }

    func testLegacyMigrationRetainsPlaintextWhenExistingReferenceDoesNotMatch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = LocalEncryptedContentStore(
            keyProvider: InMemoryContentKeyProvider(),
            directoryURL: temporaryDirectory
        )
        let legacy = CaptureRecord(type: CaptureKind.text.rawValue, rawContent: "Keep this recoverable")
        let mismatchedReference = try store.store(
            Data("different ciphertext".utf8),
            recordID: legacy.id,
            recordType: .capture,
            purpose: .captureBody
        )
        legacy.encryptedContentReference = try mismatchedReference.serialized()
        context.insert(legacy)
        try context.save()

        let result = LegacyCaptureMigrationService(contentStore: store).migrateIfNeeded(in: context)

        XCTAssertEqual(result.migratedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(legacy.rawContent, "Keep this recoverable")
    }

    func testLegacyMigrationRollsBackStagedEncryptedFilesWhenAnotherFieldCannotBeRead() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = LocalEncryptedContentStore(
            keyProvider: InMemoryContentKeyProvider(),
            directoryURL: temporaryDirectory
        )
        let legacy = CaptureRecord(type: CaptureKind.text.rawValue, rawContent: "Do not partially migrate")
        legacy.attachmentPath = temporaryDirectory.appendingPathComponent("missing-legacy-attachment.bin").path
        context.insert(legacy)
        try context.save()

        let result = LegacyCaptureMigrationService(contentStore: store).migrateIfNeeded(in: context)

        XCTAssertEqual(result.migratedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(legacy.rawContent, "Do not partially migrate")
        XCTAssertNil(legacy.encryptedContentReference)
        XCTAssertTrue(
            (try? FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path).isEmpty) ?? true
        )
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

    func testStartCleanDeletesSwiftDataEvenWhenKeyAndFileCleanupPartiallyFail() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(PersonRecord(fullName: "Still removed"))
        try context.save()

        let resetStore = FailingResetStore(failKeyDestruction: true, failFileDeletion: true)
        XCTAssertThrowsError(
            try LocalDataResetService(encryptedContentStore: resetStore).wipeAllLocalContent(in: context)
        ) { error in
            XCTAssertEqual(
                error as? LocalDataResetError,
                LocalDataResetError(failedComponents: [.deviceKey, .encryptedFiles])
            )
        }

        XCTAssertTrue(resetStore.didAttemptKeyDestruction)
        XCTAssertTrue(resetStore.didAttemptFileDeletion)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PersonRecord>()).isEmpty)
    }

    func testStartCleanStillAttemptsEncryptionCleanupWhenSwiftDataIsUnavailable() {
        let resetStore = FailingResetStore(failKeyDestruction: false, failFileDeletion: false)

        XCTAssertThrowsError(
            try LocalDataResetService(encryptedContentStore: resetStore).wipeAllLocalContent(in: nil)
        ) { error in
            XCTAssertEqual(
                error as? LocalDataResetError,
                LocalDataResetError(failedComponents: [.swiftData])
            )
        }

        XCTAssertTrue(resetStore.didAttemptKeyDestruction)
        XCTAssertTrue(resetStore.didAttemptFileDeletion)
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

final class FailingResetStore: LocalEncryptedContentResetting {
    let failKeyDestruction: Bool
    let failFileDeletion: Bool
    private(set) var didAttemptKeyDestruction = false
    private(set) var didAttemptFileDeletion = false

    init(failKeyDestruction: Bool, failFileDeletion: Bool) {
        self.failKeyDestruction = failKeyDestruction
        self.failFileDeletion = failFileDeletion
    }

    func destroyKey() throws {
        didAttemptKeyDestruction = true
        if failKeyDestruction { throw TestResetFailure.failed }
    }

    func deleteAllFiles() throws {
        didAttemptFileDeletion = true
        if failFileDeletion { throw TestResetFailure.failed }
    }
}

private enum TestResetFailure: Error {
    case failed
}
