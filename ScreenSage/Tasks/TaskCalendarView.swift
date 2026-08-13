import SwiftUI

struct TaskCalendarView: View {
    @Binding var selectedDate: Date
    let tasks: [ScreenieTask]
    let toggleCompletion: (UUID) -> Void

    private var selectedTasks: [ScreenieTask] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        ScrollView {
            DatePicker("Due date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 10)

            Divider().opacity(0.3)

            if selectedTasks.isEmpty {
                Text("No tasks due on this date")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                ForEach(selectedTasks) { task in
                    TaskRowView(task: task) { toggleCompletion(task.id) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }
}
