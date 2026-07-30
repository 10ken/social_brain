import SwiftData
import XCTest
@testable import SocialBrain

@MainActor
final class RecordLifecycleServiceTests: XCTestCase {
    func testPersonSoftDeleteRemovesJunctionsAndClearsOptionalReferences() throws {
        let context = ModelContext(try makeContainer())
        let person = PersonRecord(fullName: "Alex")
        let otherPerson = PersonRecord(fullName: "Blair")
        let group = GroupRecord(name: "Friends")
        let membership = GroupMembershipRecord(groupID: group.id, personID: person.id)
        let relationship = RelationshipRecord(
            personAID: person.id,
            personBID: otherPerson.id,
            relationshipType: "friend"
        )
        let event = SocialEventRecord(title: "Dinner")
        let attendee = EventAttendeeRecord(eventID: event.id, personID: person.id)
        let memory = MemoryRecord(content: "Alex prefers tea", memoryType: "preference")
        memory.personID = person.id
        let reminder = ReminderRecord(title: "Follow up")
        reminder.personID = person.id
        context.insert(person)
        context.insert(otherPerson)
        context.insert(group)
        context.insert(membership)
        context.insert(relationship)
        context.insert(event)
        context.insert(attendee)
        context.insert(memory)
        context.insert(reminder)
        try context.save()

        XCTAssertTrue(RecordLifecycleService().softDelete(person: person, in: context))

        XCTAssertNotNil(person.deletedAt)
        XCTAssertNotNil(membership.deletedAt)
        XCTAssertNotNil(relationship.deletedAt)
        XCTAssertNotNil(attendee.deletedAt)
        XCTAssertNil(memory.personID)
        XCTAssertNil(reminder.personID)
    }

    func testArchiveAndRestorePreserveExistingLinks() throws {
        let context = ModelContext(try makeContainer())
        let group = GroupRecord(name: "Book club")
        let event = SocialEventRecord(title: "Discussion")
        event.groupID = group.id
        context.insert(group)
        context.insert(event)
        try context.save()

        let lifecycle = RecordLifecycleService()
        XCTAssertTrue(lifecycle.archive(group, in: context))
        XCTAssertNotNil(group.archivedAt)
        XCTAssertEqual(event.groupID, group.id)

        XCTAssertTrue(lifecycle.restore(group, in: context))
        XCTAssertNil(group.archivedAt)
        XCTAssertEqual(event.groupID, group.id)
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
