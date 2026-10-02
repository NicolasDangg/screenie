import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDueDate = true
    @State private var dueDate = Date.now
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage = ""
    /// Where the task will be saved, shown so a Reminders or Calendar destination isn't a surprise.
    let destinationName: String
    let add: (ScreenieTask) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("New Task")
                    .font(.title2)
                    .bold()
                Spacer()
                Text("Saves to \(destinationName)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("Title", text: $title)
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate)
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)
            .disabled(isSaving)

            if !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                if isSaving {
                    ProgressView().controlSize(.small)
                }
                Button("Cancel", role: .cancel, action: dismiss.callAsFunction)
                Button("Add", action: addTask)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .frame(minHeight: 310)
    }

    /// Closes only after the save succeeds; on failure the draft stays for another try.
    private func addTask() {
        let task = ScreenieTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        errorMessage = ""
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await add(task)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
