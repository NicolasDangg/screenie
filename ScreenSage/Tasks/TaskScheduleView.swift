import SwiftUI

struct TaskScheduleView: View {
    let schedule: TaskSchedule
    let isAddingToCalendar: Bool
    let wasAddedToCalendar: Bool
    let dismiss: () -> Void
    let addToCalendar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Schedule hint", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Button("Dismiss schedule hint", systemImage: "xmark", action: dismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("Dismiss schedule hint")
            }
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

            Button(action: addToCalendar) {
                HStack {
                    if isAddingToCalendar {
                        ProgressView()
                            .controlSize(.small)
                        Text("Adding…")
                    } else {
                        Label(
                            wasAddedToCalendar ? "Added to Calendar" : "Add to Apple Calendar",
                            systemImage: wasAddedToCalendar ? "checkmark" : "calendar.badge.plus"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAddingToCalendar || wasAddedToCalendar)
        }
        .padding(12)
    }
}
