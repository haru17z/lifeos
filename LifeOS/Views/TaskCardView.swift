import SwiftUI

// MARK: - TaskCardView

struct TaskCardView: View {
    let task: LifeTask
    var onLocationTap: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(taskTypeColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formattedTimeLabel)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    if let location = task.location, !location.isEmpty {
                        Button {
                            onLocationTap?(location)
                        } label: {
                            Label(location, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Text(task.taskType.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(taskTypeColor.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(taskTypeColor.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // MARK: Dynamic Time Formatting

    private var formattedTimeLabel: String {
        let timePart = formattedTimeRange
        let prefix = dateRelativePrefix

        if let prefix = prefix {
            return "\(prefix) \(timePart)"
        }
        return timePart
    }

    /// Returns the time range portion — either exact times or fuzzy display string.
    /// "Anytime" placeholders are stripped per Spec 2a.
    private var formattedTimeRange: String {
        if task.isExactTime,
           let start = task.exactStartTime,
           let end = task.exactEndTime {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return "\(fmt.string(from: start)) - \(fmt.string(from: end))"
        }
        if task.isExactTime,
           let start = task.exactStartTime {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return fmt.string(from: start)
        }
        if task.timeDisplay.isEmpty || task.timeDisplay == "Anytime" {
            return ""
        }
        return task.timeDisplay
    }

    /// Returns a date-relative prefix, or nil for today.
    /// Past dates use "MM-dd". Chinese holidays rendered as names.
    private var dateRelativePrefix: String? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: task.targetDate)
        let today = calendar.startOfDay(for: Date.now)
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        let isChinese = lang == "zh-Hans"

        if targetDay == today {
            return nil
        } else if targetDay == calendar.date(byAdding: .day, value: 1, to: today) {
            return L10n.timeTomorrow
        } else if targetDay == calendar.date(byAdding: .day, value: -1, to: today) {
            return L10n.timeYesterday
        } else if isChinese, let holiday = chineseHolidayName(for: targetDay) {
            return holiday
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM-dd"
            return fmt.string(from: task.targetDate)
        }
    }

    private var taskTypeColor: Color {
        switch task.taskType {
        case .study:    return .blue
        case .health:   return .green
        case .finance:  return .orange
        case .vision:   return .purple
        case .general:  return .gray
        }
    }
}

// MARK: - Chinese Holiday Lookup

/// Returns the Chinese holiday name for a given date, or nil.
/// Covers fixed-date holidays and hardcoded lunar holidays for 2026.
func chineseHolidayName(for date: Date) -> String? {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.month, .day, .year], from: date)
    guard let month = components.month, let day = components.day, let year = components.year else { return nil }

    // Fixed solar holidays
    switch (month, day) {
    case (1, 1):   return "元旦"
    case (5, 1):   return "劳动节"
    case (10, 1):  return "国庆节"
    case (12, 25): return "圣诞节"
    default: break
    }

    // Lunar holidays — hardcoded approximate Gregorian dates
    // These shift each year; entries cover 2025–2026
    switch (year, month, day) {
    // 2026 lunar holidays (approximate)
    case (2026, 2, 17): return "春节"
    case (2026, 4, 5):  return "清明节"
    case (2026, 6, 19): return "端午节"
    case (2026, 10, 4): return "中秋节"
    // 2025 lunar holidays (approximate)
    case (2025, 1, 29): return "春节"
    case (2025, 4, 4):  return "清明节"
    case (2025, 6, 7):  return "端午节"
    case (2025, 9, 29): return "中秋节"
    default: break
    }

    return nil
}
