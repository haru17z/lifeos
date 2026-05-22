import SwiftUI
import SwiftData

// MARK: - ScheduleHistoryView

struct ScheduleHistoryView: View {

    @Query(sort: \LifeTask.targetDate, order: .reverse) private var allTasks: [LifeTask]
    @Environment(\.dismiss) private var dismiss

    @AppStorage("language") private var language = "en"

    private var pastTasks: [LifeTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date.now)
        return allTasks.filter { $0.targetDate < startOfToday }
    }

    private var groupedPastTasks: [(date: Date, tasks: [LifeTask])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: pastTasks) { task in
            calendar.startOfDay(for: task.targetDate)
        }
        return grouped
            .sorted { $0.key > $1.key }  // newest first
            .map { (date: $0.key, tasks: $0.value.sorted { $0.startTime < $1.startTime }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pastTasks.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedPastTasks, id: \.date) { group in
                            Section {
                                ForEach(group.tasks) { task in
                                    pastTaskRow(task)
                                }
                            } header: {
                                Text(sectionHeaderText(for: group.date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.scheduleHistory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.noPastTasks)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Past Task Row

    private func pastTaskRow(_ task: LifeTask) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(taskTypeColor(for: task))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(task.timeDisplay)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    if let location = task.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status badge
            if task.isCompleted {
                Label(L10n.completed, systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Label(L10n.incomplete, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: Section Header

    private func sectionHeaderText(for date: Date) -> String {
        let calendar = Calendar.current
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        let isChinese = lang == "zh-Hans"

        if calendar.isDateInYesterday(date) {
            return L10n.timeYesterday
        } else if isChinese, let holiday = chineseHolidayName(for: date) {
            return holiday
        } else if calendar.isDate(date, equalTo: Date.now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = isChinese ? "M月d日" : "MM-dd"
            formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en")
            return formatter.string(from: date)
        }
    }

    private func taskTypeColor(for task: LifeTask) -> Color {
        switch task.taskType {
        case .study:    return .blue
        case .health:   return .green
        case .finance:  return .orange
        case .vision:   return .purple
        case .general:  return .gray
        }
    }
}

#Preview {
    ScheduleHistoryView()
}
