import SwiftData
import SwiftUI

private enum AppTab: Hashable {
    case home, calendar, capture, communities, recall
}

struct AppContainerView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            CalendarPlaceholderView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)
            CapturePlaceholderView()
                .tabItem { Label("Capture", systemImage: "plus.circle.fill") }
                .tag(AppTab.capture)
            PeopleView()
                .tabItem { Label("Communities", systemImage: "person.2") }
                .tag(AppTab.communities)
            RecallPlaceholderView()
                .tabItem { Label("Recall", systemImage: "sparkles") }
                .tag(AppTab.recall)
        }
        .tint(.teal)
    }
}

private struct HomeView: View {
    @Query(sort: \SocialEventRecord.startTime) private var events: [SocialEventRecord]
    @Query(sort: \ReminderRecord.dueDate) private var allReminders: [ReminderRecord]

    private var reminders: [ReminderRecord] { allReminders.filter { !$0.completed } }

    var body: some View {
        NavigationStack {
            List {
                Section("This Week") {
                    if events.isEmpty { ContentUnavailableView("No upcoming events", systemImage: "calendar") }
                    ForEach(events.prefix(5)) { event in
                        VStack(alignment: .leading) {
                            Text(event.title).font(.headline)
                            if let startTime = event.startTime { Text(startTime, style: .date).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section("Follow-ups") {
                    if reminders.isEmpty { Text("Nothing needs attention.").foregroundStyle(.secondary) }
                    ForEach(reminders.prefix(5)) { reminder in
                        Label(reminder.title, systemImage: "circle")
                    }
                }
            }
            .navigationTitle("Social Brain")
        }
    }
}

private struct PeopleView: View {
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @State private var showingAddPerson = false

    var body: some View {
        NavigationStack {
            List(people) { person in
                VStack(alignment: .leading) {
                    Text(person.fullName).font(.headline)
                    if let nickname = person.nickname, !nickname.isEmpty { Text(nickname).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("People")
            .toolbar {
                Button("Add", systemImage: "plus") { showingAddPerson = true }
            }
            .sheet(isPresented: $showingAddPerson) { AddPersonView() }
        }
    }
}

private struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Full name", text: $name)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            .navigationTitle("Add Person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(PersonRecord(fullName: name, email: email.isEmpty ? nil : email))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CalendarPlaceholderView: View {
    var body: some View { ContentUnavailableView("Calendar", systemImage: "calendar", description: Text("Calendar and EventKit integration are next.")) }
}

private struct CapturePlaceholderView: View {
    var body: some View { ContentUnavailableView("Capture", systemImage: "plus.circle", description: Text("Text, screenshots, voice, and shared emails are reviewed here.")) }
}

private struct RecallPlaceholderView: View {
    var body: some View { ContentUnavailableView("Recall", systemImage: "sparkles", description: Text("Ask your reviewed social memory.")) }
}
