import SwiftData

/// Local lifecycle rules used by editors and tests. Archive retains every link;
/// soft delete hides the selected record, soft-deletes junctions, and clears
/// optional links from retained records. Start Clean is the only permanent
/// removal mechanism.
@MainActor
final class RecordLifecycleService {
    @discardableResult
    func archive(_ record: some SyncableRecord, in context: ModelContext) -> Bool {
        record.archivedAt = .now
        record.updatedAt = .now
        return saveLocalChanges(context)
    }

    @discardableResult
    func restore(_ record: some SyncableRecord, in context: ModelContext) -> Bool {
        record.archivedAt = nil
        record.updatedAt = .now
        return saveLocalChanges(context)
    }

    @discardableResult
    func softDelete(person: PersonRecord, in context: ModelContext) -> Bool {
        do {
            let memberships = try context.fetch(FetchDescriptor<GroupMembershipRecord>())
            let relationships = try context.fetch(FetchDescriptor<RelationshipRecord>())
            let attendees = try context.fetch(FetchDescriptor<EventAttendeeRecord>())
            let memories = try context.fetch(FetchDescriptor<MemoryRecord>())
            let reminders = try context.fetch(FetchDescriptor<ReminderRecord>())
            markDeleted(person)
            for membership in memberships where membership.personID == person.id { markDeleted(membership) }
            for relationship in relationships where relationship.personAID == person.id || relationship.personBID == person.id { markDeleted(relationship) }
            for attendee in attendees where attendee.personID == person.id { markDeleted(attendee) }
            for memory in memories where memory.personID == person.id { memory.personID = nil; memory.updatedAt = .now }
            for reminder in reminders where reminder.personID == person.id { reminder.personID = nil; reminder.updatedAt = .now }
            return saveLocalChanges(context)
        } catch {
            LocalPersistenceFailureReporter.shared.reportFailure()
            return false
        }
    }

    @discardableResult
    func softDelete(group: GroupRecord, in context: ModelContext) -> Bool {
        do {
            let memberships = try context.fetch(FetchDescriptor<GroupMembershipRecord>())
            let events = try context.fetch(FetchDescriptor<SocialEventRecord>())
            let memories = try context.fetch(FetchDescriptor<MemoryRecord>())
            let reminders = try context.fetch(FetchDescriptor<ReminderRecord>())
            markDeleted(group)
            for membership in memberships where membership.groupID == group.id { markDeleted(membership) }
            for event in events where event.groupID == group.id { event.groupID = nil; event.updatedAt = .now }
            for memory in memories where memory.groupID == group.id { memory.groupID = nil; memory.updatedAt = .now }
            for reminder in reminders where reminder.groupID == group.id { reminder.groupID = nil; reminder.updatedAt = .now }
            return saveLocalChanges(context)
        } catch {
            LocalPersistenceFailureReporter.shared.reportFailure()
            return false
        }
    }

    @discardableResult
    func softDelete(event: SocialEventRecord, in context: ModelContext) -> Bool {
        do {
            let attendees = try context.fetch(FetchDescriptor<EventAttendeeRecord>())
            let memories = try context.fetch(FetchDescriptor<MemoryRecord>())
            markDeleted(event)
            for attendee in attendees where attendee.eventID == event.id { markDeleted(attendee) }
            for memory in memories where memory.eventID == event.id { memory.eventID = nil; memory.updatedAt = .now }
            return saveLocalChanges(context)
        } catch {
            LocalPersistenceFailureReporter.shared.reportFailure()
            return false
        }
    }

    @discardableResult
    func softDelete(_ record: some SyncableRecord, in context: ModelContext) -> Bool {
        markDeleted(record)
        return saveLocalChanges(context)
    }

    private func markDeleted(_ record: some SyncableRecord) {
        record.deletedAt = .now
        record.archivedAt = nil
        record.updatedAt = .now
    }
}
