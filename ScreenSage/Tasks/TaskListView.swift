import SwiftUI

struct TaskListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCompleted = false
    let sections: [TaskAgendaSection]
    @Binding var filter: TaskAgendaFilter
    let schedule: TaskSchedule?
    let errorMessage: String
    let isParsingTask: Bool
    let isRequestingSchedule: Bool
    let isAddingScheduleToCalendar: Bool
    let didAddScheduleToCalendar: Bool
    let needsConnection: Bool
    let connect: () -> Void
    let toggleCompletion: (TaskAgendaItem) -> Void
    let updateDueDate: (UUID, Date?) -> Void
    let requestDelete: (ScreenieTask) -> Void
    let dismissSchedule: () -> Void
    let addScheduleToCalendar: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                filterBar

                if let schedule {
                    TaskScheduleView(
                        schedule: schedule,
                        isAddingToCalendar: isAddingScheduleToCalendar,
                        wasAddedToCalendar: didAddScheduleToCalendar,
                        dismiss: dismissSchedule,
                        addToCalendar: addScheduleToCalendar
                    )
                    .padding(.horizontal, 6)
                }

                if sections.isEmpty {
                    ContentUnavailableView(
                        filter == .all ? "Nothing to do" : "No \(filter.rawValue) items",
                        systemImage: "checklist",
                        description: Text("Add a task below or type /task in chat.")
                    )
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.75 }
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 0) {
                            sectionHeader(section)
                            ForEach(section.kind == .completed && !showsCompleted ? [] : section.items) { item in
                                TaskRowView(
                                    item: item,
                                    timeLabel: Self.timeLabel(for: item, in: section.kind),
                                    toggleCompletion: { toggleCompletion(item) },
                                    updateDueDate: updateDueDate,
                                    delete: requestDelete
                                )
                            }
                        }
                    }
                }

                if isParsingTask {
                    ProgressView("Understanding task…").controlSize(.small).padding(.horizontal, 8)
                }
                if isRequestingSchedule {
                    ProgressView("Finding time…").controlSize(.small).padding(.horizontal, 8)
                }
                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                }
                if needsConnection {
                    connectPrompt
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: sections)
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: showsCompleted)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private func sectionHeader(_ section: TaskAgendaSection) -> some View {
        let title = Text(section.title)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.4)
        if section.kind == .completed {
            Button {
                showsCompleted.toggle()
            } label: {
                HStack(spacing: 5) {
                    title
                    Text("\(section.items.count)")
                        .font(.system(size: 11))
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsCompleted ? "Hide completed" : "Show \(section.items.count) completed")
        } else {
            title
                .foregroundStyle(section.kind == .overdue ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(TaskAgendaFilter.allCases) { option in
                Button { filter = option } label: {
                    HStack(spacing: 5) {
                        switch option {
                        case .all: EmptyView()
                        case .screenie: TaskSourceMark(kind: .task, tint: .accentColor)
                        case .reminders: TaskSourceMark(kind: .reminder, tint: .secondary)
                        case .events: TaskSourceMark(kind: .event, tint: .secondary)
                        }
                        Text(option.rawValue)
                    }
                    .font(.system(size: 12, weight: filter == option ? .semibold : .regular))
                    .foregroundStyle(filter == option ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(filter == option ? Color.primary.opacity(0.12) : .clear, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
    }

    private var connectPrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .foregroundStyle(.secondary)
            Text("Show your Reminders and Calendar events here.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Connect", action: connect)
                .controlSize(.small)
        }
        .padding(10)
        .background(.primary.opacity(0.05), in: .rect(cornerRadius: 10))
    }

    static func timeLabel(for item: TaskAgendaItem, in section: TaskAgendaSection.Kind) -> String {
        guard let date = item.date else { return "" }
        switch section {
        case .overdue, .later:
            return item.hasTime
                ? date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                : date.formatted(.dateTime.month(.abbreviated).day())
        case .completed:
            return ""
        case .day, .someday:
            guard item.hasTime else { return item.kind == .event ? "All day" : "" }
            let start = date.formatted(date: .omitted, time: .shortened)
            guard item.kind == .event, let end = item.endDate else { return start }
            return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
        }
    }
}
