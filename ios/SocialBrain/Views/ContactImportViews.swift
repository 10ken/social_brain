import Contacts
import SwiftData
import SwiftUI
import UIKit

private enum ContactImportAction: String, CaseIterable, Identifiable {
    case add
    case update
    case skip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .add: return "Add person"
        case .update: return "Update match"
        case .skip: return "Skip"
        }
    }
}

private struct ContactDuplicateMatch {
    let person: PersonRecord
    let reason: String
    let isExactContactMatch: Bool
}

/// Imports only contacts selected in the system picker. Every selected contact
/// is reviewed here before it can create or update a local person record.
@MainActor
struct ContactImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonRecord.fullName) private var allPeople: [PersonRecord]

    private let contactService: any ContactImporting
    private let settingsOpener: any ApplicationSettingsOpening
    @State private var authorizationState: ContactAuthorizationState = .unavailable
    @State private var showingPicker = false
    @State private var candidates: [ContactImportCandidate] = []
    @State private var actions: [String: ContactImportAction] = [:]
    @State private var message: String?

    init(
        contactService: any ContactImporting = DeviceContactImportService(),
        settingsOpener: any ApplicationSettingsOpening = SystemApplicationSettingsOpener()
    ) {
        self.contactService = contactService
        self.settingsOpener = settingsOpener
    }

    private var people: [PersonRecord] {
        allPeople.filter(\.isVisibleInDefaultLists)
    }

    var body: some View {
        NavigationStack {
            List {
                authorizationSection

                if candidates.isEmpty {
                    ContentUnavailableView(
                        "Choose contacts to review",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Social Brain reads only the contacts you choose in the system picker.")
                    )
                } else {
                    Section("Review \(candidates.count) selected") {
                        ForEach(candidates) { candidate in
                            let match = duplicate(for: candidate, among: people)
                            ContactImportCandidateRow(candidate: candidate, match: match)
                            Picker("Action", selection: actionBinding(for: candidate, match: match)) {
                                ForEach(availableActions(for: match)) { action in
                                    Text(action.label).tag(action)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Section {
                        Button("Apply Reviewed Imports", action: applyReviewedImports)
                    } footer: {
                        Text("Existing details are never overwritten automatically. An update fills only blank fields and preserves an existing contact identifier.")
                    }
                }

                if let message {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Import Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ContactPickerSheet(isPresented: $showingPicker) { selectedContacts in
                    let selected = contactService.candidates(from: selectedContacts)
                    candidates = selected
                    actions = Dictionary(
                        uniqueKeysWithValues: selected.map { candidate in
                            let match = duplicate(for: candidate, among: people)
                            return (candidate.id, defaultAction(for: match))
                        }
                    )
                    message = selected.isEmpty ? "No named contacts were selected." : nil
                }
            }
            .task {
                authorizationState = contactService.authorizationState
            }
        }
    }

    @ViewBuilder
    private var authorizationSection: some View {
        Section("Contacts") {
            switch authorizationState {
            case .authorized:
                Label("Contact access is ready", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Button("Choose Contacts", systemImage: "person.crop.circle.badge.plus") {
                    showingPicker = true
                }
            case .notDetermined:
                Label("Contact permission is needed", systemImage: "person.crop.circle.badge.questionmark")
                Button("Allow Contacts Access") {
                    Task {
                        authorizationState = await contactService.requestAccess()
                    }
                }
            case .denied:
                Label("Contact access was denied", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("You can allow access later in iOS Settings, then choose exactly which contacts to review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Settings", action: settingsOpener.openApplicationSettings)
            case .restricted:
                Label("Contact access is restricted", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text("This device does not currently permit contact access. You can still create people manually.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .unavailable:
                Label("Contacts are unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionBinding(
        for candidate: ContactImportCandidate,
        match: ContactDuplicateMatch?
    ) -> Binding<ContactImportAction> {
        Binding(
            get: { actions[candidate.id] ?? defaultAction(for: match) },
            set: { actions[candidate.id] = $0 }
        )
    }

    private func availableActions(for match: ContactDuplicateMatch?) -> [ContactImportAction] {
        match == nil ? [.add, .skip] : [.update, .skip]
    }

    private func defaultAction(for match: ContactDuplicateMatch?) -> ContactImportAction {
        match == nil ? .add : .skip
    }

    private func duplicate(
        for candidate: ContactImportCandidate,
        among people: [PersonRecord]
    ) -> ContactDuplicateMatch? {
        if let exact = people.first(where: { $0.contactIdentifier == candidate.id }) {
            return ContactDuplicateMatch(person: exact, reason: "This contact was imported before", isExactContactMatch: true)
        }

        let candidateEmails = Set(candidate.emailAddresses.map(normalizedEmail))
        if !candidateEmails.isEmpty,
           let emailMatch = people.first(where: { person in
               guard let email = person.email else { return false }
               return candidateEmails.contains(normalizedEmail(email))
           }) {
            return ContactDuplicateMatch(person: emailMatch, reason: "Matches email", isExactContactMatch: false)
        }

        let candidatePhones = Set(candidate.phoneNumbers.map(normalizedPhone).filter { !$0.isEmpty })
        if !candidatePhones.isEmpty,
           let phoneMatch = people.first(where: { person in
               guard let phoneNumber = person.phoneNumber else { return false }
               return candidatePhones.contains(normalizedPhone(phoneNumber))
           }) {
            return ContactDuplicateMatch(person: phoneMatch, reason: "Matches phone number", isExactContactMatch: false)
        }

        let normalizedCandidateName = normalizedName(candidate.fullName)
        if !normalizedCandidateName.isEmpty,
           let nameMatch = people.first(where: { normalizedName($0.fullName) == normalizedCandidateName }) {
            return ContactDuplicateMatch(person: nameMatch, reason: "Matches name", isExactContactMatch: false)
        }
        return nil
    }

    private func applyReviewedImports() {
        var workingPeople = people
        var added = 0
        var updated = 0
        var skipped = 0

        for candidate in candidates {
            let match = duplicate(for: candidate, among: workingPeople)
            let action = actions[candidate.id] ?? defaultAction(for: match)
            switch action {
            case .skip:
                skipped += 1
            case .add:
                // Re-check against records added in this same review pass so
                // two selected contacts cannot create a duplicate person.
                guard match == nil else {
                    skipped += 1
                    continue
                }
                let person = PersonRecord(fullName: candidate.fullName, email: candidate.primaryEmail)
                apply(candidate, to: person, preservingExistingValues: false)
                modelContext.insert(person)
                workingPeople.append(person)
                added += 1
            case .update:
                guard let person = match?.person else {
                    skipped += 1
                    continue
                }
                apply(candidate, to: person, preservingExistingValues: true)
                updated += 1
            }
        }

        guard saveLocalChanges(modelContext) else {
            modelContext.rollback()
            message = "The reviewed contacts could not be saved."
            return
        }
        let details = [
            added > 0 ? "\(added) added" : nil,
            updated > 0 ? "\(updated) updated" : nil,
            skipped > 0 ? "\(skipped) skipped" : nil
        ].compactMap { $0 }.joined(separator: ", ")
        message = details.isEmpty ? "No contacts were changed." : "Contact import complete: \(details)."
    }

    private func apply(
        _ candidate: ContactImportCandidate,
        to person: PersonRecord,
        preservingExistingValues: Bool
    ) {
        if !preservingExistingValues || person.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            person.fullName = candidate.fullName
        }
        if !preservingExistingValues || person.nickname == nil {
            person.nickname = candidate.nickname
        }
        if !preservingExistingValues || person.email == nil {
            person.email = candidate.primaryEmail
        }
        if !preservingExistingValues || person.phoneNumber == nil {
            person.phoneNumber = candidate.primaryPhoneNumber
        }
        if !preservingExistingValues || person.birthday == nil {
            person.birthday = candidate.birthday
        }
        if person.contactIdentifier == nil {
            person.contactIdentifier = candidate.id
        }
        person.isImported = true
        if person.evidenceText == nil {
            person.evidenceText = "Imported from a contact you selected."
        }
        person.markUpdated()
    }

    private func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedPhone(_ value: String) -> String {
        value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.map { String($0) }.joined()
    }

    private func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct ContactImportCandidateRow: View {
    let candidate: ContactImportCandidate
    let match: ContactDuplicateMatch?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(candidate.fullName)
                .font(.headline)
            if let email = candidate.primaryEmail {
                Text(email).font(.footnote).foregroundStyle(.secondary)
            } else if let phone = candidate.primaryPhoneNumber {
                Text(phone).font(.footnote).foregroundStyle(.secondary)
            }
            if let match {
                Label("\(match.reason): \(match.person.fullName)", systemImage: match.isExactContactMatch ? "checkmark.circle" : "person.crop.circle.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(match.isExactContactMatch ? .green : .orange)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ContactPickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSelected: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onSelected: onSelected)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private var isPresented: Binding<Bool>
        private let onSelected: ([CNContact]) -> Void

        init(isPresented: Binding<Bool>, onSelected: @escaping ([CNContact]) -> Void) {
            self.isPresented = isPresented
            self.onSelected = onSelected
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            finish(with: contacts)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            finish(with: [contact])
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            Task { @MainActor [isPresented] in
                isPresented.wrappedValue = false
            }
        }

        private func finish(with contacts: [CNContact]) {
            Task { @MainActor [isPresented, onSelected] in
                onSelected(contacts)
                isPresented.wrappedValue = false
            }
        }
    }
}
