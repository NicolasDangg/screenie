import SwiftUI

struct TaskCalendarView: View {
    let tasks: [ScreenieTask]
    let errorMessage: String
    let isParsingTask: Bool
    let isRequestingSchedule: Bool
    let toggleCompletion: (UUID) -> Void
    let updateDueDate: (UUID, Date?) -> Void
    let requestDelete: (ScreenieTask) -> Void

    @State private var displayedMonth: Date
    @State private var selectedWeekStart: Date
    @State private var scrollWeek: Date?

    private let calendar: Calendar
    private let today: Date
    private let weekStarts: [Date]

    init(
        tasks: [ScreenieTask],
        errorMessage: String,
        isParsingTask: Bool,
        isRequestingSchedule: Bool,
        toggleCompletion: @escaping (UUID) -> Void,
        updateDueDate: @escaping (UUID, Date?) -> Void,
        requestDelete: @escaping (ScreenieTask) -> Void,
        calendar: Calendar = .autoupdatingCurrent,
        today: Date = .now
    ) {
        self.tasks = tasks
        self.errorMessage = errorMessage
        self.isParsingTask = isParsingTask
        self.isRequestingSchedule = isRequestingSchedule
        self.toggleCompletion = toggleCompletion
        self.updateDueDate = updateDueDate
        self.requestDelete = requestDelete
        self.calendar = calendar
        self.today = today

        let weekStart = Self.weekDates(containing: today, calendar: calendar).first ?? today
        _displayedMonth = State(initialValue: today)
        _selectedWeekStart = State(initialValue: weekStart)
        _scrollWeek = State(initialValue: weekStart)
        // ponytail: a finite ±10-year pager avoids an infinite data source; extend if long-range planning needs it.
        weekStarts = (-520...520).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0, to: weekStart)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            monthGrid
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            Divider().opacity(0.3)

            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(weekStarts, id: \.self) { weekStart in
                            weeklyAgenda(starting: weekStart)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(weekStart)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollWeek)
            }
        }
        .onChange(of: scrollWeek) { _, weekStart in
            guard let weekStart else { return }
            selectedWeekStart = weekStart
            displayedMonth = calendar.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
        }
    }

    static func monthDates(containing date: Date, calendar: Calendar) -> [Date] {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start else {
            return []
        }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthHeader: some View {
        HStack(spacing: 4) {
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            calendarButton("Previous month", systemImage: "chevron.left") { moveMonth(-1) }
            calendarButton("Today", systemImage: "circle.fill", action: showToday)
                .font(.system(size: 7))
            calendarButton("Next month", systemImage: "chevron.right") { moveMonth(1) }
        }
        .padding(.horizontal, 13)
        .frame(height: 38)
    }

    private var weekdayHeader: some View {
        let formatter = DateFormatter()
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
        let offset = max(0, min(symbols.count, calendar.firstWeekday - 1))
        let ordered = Array(symbols.dropFirst(offset) + symbols.prefix(offset))

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 0
        ) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(height: 18)
            }
        }
        .padding(.horizontal, 10)
    }

    private var monthGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            ForEach(Self.monthDates(containing: displayedMonth, calendar: calendar), id: \.self) { date in
                TaskCalendarDayCell(
                    date: date,
                    isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                    isToday: calendar.isDate(date, inSameDayAs: today),
                    isSelectedWeek: calendar.isDate(date, equalTo: selectedWeekStart, toGranularity: .weekOfYear),
                    tasks: tasks.filter { task in
                        task.dueDate.map { calendar.isDate($0, inSameDayAs: date) } == true
                    }
                ) {
                    selectWeek(containing: date)
                }
            }
        }
    }

    private func weeklyAgenda(starting weekStart: Date) -> some View {
        let days = Self.weekDates(containing: weekStart, calendar: calendar)
        let datedDays = days.filter { day in
            tasks.contains { task in
                task.dueDate.map { calendar.isDate($0, inSameDayAs: day) } == true
            }
        }

        return ScrollView {
            LazyVStack(spacing: 0) {
                if datedDays.isEmpty {
                    ContentUnavailableView(
                        "No tasks this week",
                        systemImage: "calendar",
                        description: Text("Swipe horizontally to view another week.")
                    )
                    .frame(minHeight: 120)
                } else {
                    ForEach(datedDays, id: \.self) { day in
                        agendaHeader(for: day)
                        ForEach(tasks.filter { task in
                            task.dueDate.map { calendar.isDate($0, inSameDayAs: day) } == true
                        }) { task in
                            TaskRowView(
                                task: task,
                                isAgenda: true,
                                toggleCompletion: { toggleCompletion(task.id) },
                                updateDueDate: { updateDueDate(task.id, $0) },
                                delete: { requestDelete(task) }
                            )
                        }
                    }
                }

                if isParsingTask {
                    ProgressView("Understanding task…").controlSize(.small).padding()
                }
                if isRequestingSchedule {
                    ProgressView("Finding study time…").controlSize(.small).padding()
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func agendaHeader(for date: Date) -> some View {
        HStack {
            Text(dayLabel(for: date))
            Spacer()
            Text(date, format: .dateTime.month(.abbreviated).day())
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 13)
        .padding(.top, 9)
        .padding(.bottom, 3)
    }

    private func dayLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func calendarButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .contentShape(.rect)
    }

    private func moveMonth(_ amount: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: amount, to: displayedMonth),
              let monthStart = calendar.dateInterval(of: .month, for: nextMonth)?.start else { return }
        displayedMonth = monthStart
        selectWeek(containing: monthStart)
    }

    private func showToday() {
        displayedMonth = today
        selectWeek(containing: today)
    }

    private func selectWeek(containing date: Date) {
        guard let weekStart = Self.weekDates(containing: date, calendar: calendar).first else { return }
        selectedWeekStart = weekStart
        scrollWeek = weekStart
    }
}

private struct TaskCalendarDayCell: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelectedWeek: Bool
    let tasks: [ScreenieTask]
    let select: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(spacing: 1) {
                Text(date, format: .dateTime.day())
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 2) {
                    ForEach(Array(tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                        Circle()
                            .fill(task.isCompleted ? Color.secondary.opacity(0.55) : Color.accentColor)
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(isInDisplayedMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .frame(maxWidth: .infinity, minHeight: 29)
            .background {
                if isSelectedWeek {
                    RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12))
                }
            }
            .overlay {
                if isToday || isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isToday ? Color.accentColor : Color.secondary.opacity(0.45), lineWidth: isToday ? 1.6 : 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(tasks.isEmpty ? "No tasks" : "\(tasks.count) tasks")
    }
}
