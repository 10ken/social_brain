import Contacts
import Foundation

enum ContactAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable

    var canSelectContacts: Bool { self == .authorized }
}

/// A contact is represented only after a person selects it in the system
/// picker. `id` is CNContact.identifier and is the stable import key.
struct ContactImportCandidate: Identifiable, Hashable {
    let id: String
    let fullName: String
    let nickname: String?
    let emailAddresses: [String]
    let phoneNumbers: [String]
    let birthday: String?

    var primaryEmail: String? { emailAddresses.first }
    var primaryPhoneNumber: String? { phoneNumbers.first }
}

@MainActor
protocol ContactImporting: AnyObject {
    var authorizationState: ContactAuthorizationState { get }
    func requestAccess() async -> ContactAuthorizationState
    func candidates(from contacts: [CNContact]) -> [ContactImportCandidate]
}

@MainActor
final class DeviceContactImportService: ContactImporting {
    private let contactStore: CNContactStore

    init(contactStore: CNContactStore = CNContactStore()) {
        self.contactStore = contactStore
    }

    var authorizationState: ContactAuthorizationState {
        Self.authorizationState(for: CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestAccess() async -> ContactAuthorizationState {
        guard authorizationState == .notDetermined else { return authorizationState }
        let granted = await withCheckedContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        return granted ? .authorized : authorizationState
    }

    func candidates(from contacts: [CNContact]) -> [ContactImportCandidate] {
        var seenIdentifiers = Set<String>()
        return contacts.compactMap { contact in
            guard !contact.identifier.isEmpty, seenIdentifiers.insert(contact.identifier).inserted else { return nil }
            let name = CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = [contact.givenName, contact.familyName, contact.nickname]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let fullName = (name?.isEmpty == false ? name : fallbackName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullName.isEmpty else { return nil }

            let emails = uniqueNonEmpty(contact.emailAddresses.map { String($0.value) })
            let phones = uniqueNonEmpty(contact.phoneNumbers.map { $0.value.stringValue })
            let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            return ContactImportCandidate(
                id: contact.identifier,
                fullName: fullName,
                nickname: nickname.isEmpty ? nil : nickname,
                emailAddresses: emails,
                phoneNumbers: phones,
                birthday: birthdayText(contact.birthday)
            )
        }
    }

    private static func authorizationState(for status: CNAuthorizationStatus) -> ContactAuthorizationState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }

    private func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private func birthdayText(_ birthday: DateComponents?) -> String? {
        guard let birthday, let month = birthday.month, let day = birthday.day else { return nil }
        if let year = birthday.year {
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
        return String(format: "%02d-%02d", month, day)
    }
}
