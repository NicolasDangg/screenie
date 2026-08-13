import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDueDate = true
    @State private var dueDate = Date.now
    @State private var notes = ""
    let add: (ScreenieTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task")
                .font(.title2)
                .bold()

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

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: dismiss.callAsFunction)
                Button("Add", action: addTask)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 310)
    }

    private func addTask() {
        add(ScreenieTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        dismiss()
    }
}
