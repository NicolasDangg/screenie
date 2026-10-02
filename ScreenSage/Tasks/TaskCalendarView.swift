import SwiftUI

/// A seven-day strip with a timeline for the selected day.
struct TaskCalendarView: View {
    let items: [TaskAgendaItem]
    @Binding var selectedDay: Date
    let errorMessage: String
    let isParsingTask: Bool
    let toggleCompletion: (TaskAgendaItem) -> Void
    let updateDueDate: (UUID, Date?) -> Void
    let requestDelete: (ScreenieTask) -> Void
    var calendar = Calendar.autoupdatingCurrent

    private var week: [Date] { TaskAgenda.weekDates(containing: selectedDay, calendar: calendar) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                stepButton("Previous week", systemImage: "chevron.left", weeks: -1)
                ForEach(week, id: \.self) { day in
                    dayButton(day)
                }
                stepButton("Next week", systemImage: "chevron.right", weeks: 1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 6)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(selectedDay, format: .dateTime.weekday(.wide).month(.wide).day())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !calendar.isDateInToday(selectedDay) {
                                Button("Today") { selectedDay = .now }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 6)

                        timeline(now: context.date)

                        if isParsingTask {
                            ProgressView("Understanding task…").controlSize(.small).padding(.top, 8)
                        }
                        if !errorMessage.isEmpty {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.orange)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, OverlayLayout.contentInset)
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder private func timeline(now: Date) -> some View {
        let dayItems = TaskAgenda.dayItems(items, on: selectedDay, calendar: calendar)
        if dayItems.isEmpty {
            Text("Nothing scheduled.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.vertical, 18)
        } else {
            let nowIndex = calendar.isDate(selectedDay, inSameDayAs: now)
                ? dayItems.firstIndex { $0.hasTime && ($0.date ?? now) > now } ?? dayItems.endIndex
                : nil
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                ForEach(Array(dayItems.enumerated()), id: \.element.id) { index, item in
                    if index == nowIndex { nowLine(now) }
                    GridRow {
                        Text(item.hasTime ? (item.date ?? now).formatted(date: .omitted, time: .shortened) : "All day")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        block(for: item)
                            .padding(.leading, 12)
                            .padding(.vertical, 3)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(.primary.opacity(0.1)).frame(width: 1)
                            }
                    }
                }
                if nowIndex == dayItems.endIndex { nowLine(now) }
            }
        }
    }

    private func nowLine(_ now: Date) -> some View {
        GridRow {
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.red)
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 7, height: 7).offset(x: -3)
                Rectangle().fill(.red).frame(height: 1.5)
            }
            .padding(.vertical, 6)
        }
        .accessibilityLabel("Now")
    }

    private func block(for item: TaskAgendaItem) -> some View {
        HStack(spacing: 8) {
            switch item.kind {
            case .event:
                TaskSourceMark(kind: .event, tint: item.tint)
            case .task, .reminder:
                TaskCheckbox(
                    isOn: item.isCompleted,
                    tint: item.tint,
                    ringColor: item.kind == .reminder ? item.tint : .secondary,
                    size: 14
                ) { toggleCompletion(item) }
                .padding(.vertical, -5)
                .padding(.horizontal, -4)
            }
            CompletableTitle(title: item.title, isCompleted: item.isCompleted, fontSize: 13)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(detail(for: item))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(item.tint.opacity(item.isCompleted ? 0.06 : 0.14), in: .rect(cornerRadius: 8))
        .contextMenu {
            if let task = item.task {
                Button("Delete", systemImage: "trash", role: .destructive) { requestDelete(task) }
            }
        }
    }

    private func detail(for item: TaskAgendaItem) -> String {
        switch item.kind {
        case .task:
            return "screenie"
        case .reminder:
            return "Reminders · \(item.sourceName)"
        case .event:
            guard item.hasTime, let start = item.date, let end = item.endDate else { return item.sourceName }
            let range = "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
            return "\(range) · \(item.sourceName)"
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let marks = Array(TaskAgenda.dayItems(items, on: day, calendar: calendar).filter { !$0.isCompleted }.prefix(3))
        return Button { selectedDay = day } label: {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 10.5, weight: .semibold))
                    .textCase(.uppercase)
                    .opacity(0.75)
                Text(day, format: .dateTime.day())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isToday && !isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                HStack(spacing: 3) {
                    ForEach(marks) { item in
                        Circle()
                            .fill(isSelected ? AnyShapeStyle(.background) : AnyShapeStyle(item.tint))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(isSelected ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
            .background(
                isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(0.05)),
                in: .rect(cornerRadius: 10)
            )
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(marks.isEmpty ? "Nothing scheduled" : "\(marks.count) items")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stepButton(_ title: String, systemImage: String, weeks: Int) -> some View {
        WeekStepButton(title: title, systemImage: systemImage) {
            selectedDay = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDay) ?? selectedDay
        }
    }
}

/// A full-height arrow beside the week strip. The frame and hit shape sit inside the label,
/// because a plain button only responds where its label draws.
private struct WeekStepButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 30, height: 60)
                .background(.primary.opacity(isHovered ? 0.08 : 0), in: .rect(cornerRadius: 10))
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .help(title)
    }
}
