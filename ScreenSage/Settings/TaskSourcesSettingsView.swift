import AppKit
import EventKit
import SwiftUI

struct TaskSourcesSettingsView: View {
    @Bindable var sources: AppleTaskSources

    var body: some View {
        Form {
            Section {
                accessRow(
                    access: sources.reminderAccess,
                    entity: .reminder,
                    privacyAnchor: "Privacy_Reminders"
                )
                Toggle(isOn: $sources.showsReminders) {
                    Text("Show reminders in Tasks")
                    Text("Checking one off in screenie completes it in Reminders.")
                }
                .disabled(sources.reminderAccess != .granted)
                if sources.showsReminders {
                    ForEach(sources.reminderLists) { list in
                        listToggle(list, isOn: Binding(
                            get: { sources.isVisible(list) },
                            set: { sources.setReminderList(list, visible: $0) }
                        ), kind: .reminder)
                    }
                }
            } header: {
                Text("Apple Reminders")
            }

            Section {
                accessRow(
                    access: sources.eventAccess,
                    entity: .event,
                    privacyAnchor: "Privacy_Calendars"
                )
                Toggle(isOn: $sources.showsEvents) {
                    Text("Show events in Tasks")
                    Text("Read-only — edit events in Calendar.")
                }
                .disabled(sources.eventAccess != .granted)
                if sources.showsEvents {
                    ForEach(sources.eventCalendars) { calendar in
                        listToggle(calendar, isOn: Binding(
                            get: { sources.isVisible(calendar) },
                            set: { sources.setCalendar(calendar, visible: $0) }
                        ), kind: .event)
                    }
                }
            } header: {
                Text("Apple Calendar")
            }

            Section {
                Picker("Save new items to", selection: $sources.newItemDestination) {
                    Text("screenie task").tag(NewItemDestination.screenie)
                    ForEach(sources.reminderLists) { list in
                        Text("Reminder — \(list.title)").tag(NewItemDestination.reminders(list.id))
                    }
                    ForEach(sources.writableEventCalendars) { calendar in
                        Text("Event — \(calendar.title)").tag(NewItemDestination.calendar(calendar.id))
                    }
                }
                Toggle(isOn: $sources.syncsTasksToCalendar) {
                    Text("Add dated screenie tasks to Calendar")
                    Text("Uses your default calendar.")
                }
            } header: {
                Text("New Items")
            } footer: {
                Text("Events are saved straight to Apple Calendar. Type when it happens, like “Lunch with Sam tomorrow 12–1”.")
            }
        }
        .formStyle(.grouped)
        .task { await sources.refresh() }
    }

    @ViewBuilder
    private func accessRow(access: AppleSourceAccess, entity: EKEntityType, privacyAnchor: String) -> some View {
        LabeledContent("Access") {
            switch access {
            case .granted:
                Label("Full access", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .notDetermined:
                Button("Allow Access…") { Task { await sources.requestAccess(to: entity) } }
            case .denied:
                Button("Open Privacy Settings") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyAnchor)")
                    if let url { NSWorkspace.shared.open(url) }
                }
            }
        }
    }

    private func listToggle(_ list: AppleSourceCalendar, isOn: Binding<Bool>, kind: TaskAgendaKind) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                TaskSourceMark(kind: kind, tint: list.color.color, size: 9)
                Text(list.title)
            }
        }
        .toggleStyle(.checkbox)
    }
}
