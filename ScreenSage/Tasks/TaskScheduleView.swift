import SwiftUI

struct TaskScheduleView: View {
    let schedule: TaskSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Schedule hint", systemImage: "wand.and.stars")
                .font(.headline)
            Text(schedule.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(schedule.suggestions) { suggestion in
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.taskTitle)
                        .bold()
                    Text(suggestion.start...suggestion.end)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(suggestion.note)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .padding(12)
    }
}
