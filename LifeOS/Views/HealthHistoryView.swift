import SwiftUI
import SwiftData

// MARK: - HealthHistoryView

struct HealthHistoryView: View {

    @Query(sort: \DietEntry.date, order: .reverse) private var dietEntries: [DietEntry]
    @Query(sort: \SleepEntry.date, order: .reverse) private var sleepEntries: [SleepEntry]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moodEntries: [MoodEntry]
    @Environment(\.dismiss) private var dismiss

    @AppStorage("language") private var language = "en"

    private var calendar: Calendar { Calendar.current }

    // Group entries by date for a combined history view
    private var groupedDates: [Date] {
        var dateSet = Set<Date>()
        let startOfToday = calendar.startOfDay(for: Date.now)
        for entry in dietEntries where entry.date < startOfToday {
            dateSet.insert(calendar.startOfDay(for: entry.date))
        }
        for entry in sleepEntries where entry.date < startOfToday {
            dateSet.insert(calendar.startOfDay(for: entry.date))
        }
        for entry in moodEntries where entry.date < startOfToday {
            dateSet.insert(calendar.startOfDay(for: entry.date))
        }
        return Array(dateSet).sorted(by: >) // newest first
    }

    var body: some View {
        NavigationStack {
            Group {
                if groupedDates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedDates, id: \.self) { date in
                            Section {
                                if let weightEntry = weightForDate(date) {
                                    weightRow(weight: weightEntry)
                                }
                                if let stepsEntry = stepsForDate(date) {
                                    stepsRow(steps: stepsEntry)
                                }
                                if let sleep = sleepForDate(date) {
                                    sleepRow(sleep)
                                }
                                let dietForDay = dietForDate(date)
                                if !dietForDay.isEmpty {
                                    dietRows(dietForDay)
                                }
                                if let mood = moodForDate(date) {
                                    moodRow(mood)
                                }
                            } header: {
                                Text(dateHeaderText(for: date))
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
            .navigationTitle(L10n.healthHistory)
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
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.noHealthHistory)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Date Helpers

    private func dateHeaderText(for date: Date) -> String {
        let isZh = language == "zh-Hans"
        if calendar.isDateInYesterday(date) {
            return L10n.timeYesterday
        } else if isZh, let holiday = chineseHolidayName(for: date) {
            return holiday
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = isZh ? "M月d日 EEEE" : "EEEE, MMM d"
            formatter.locale = Locale(identifier: isZh ? "zh_Hans" : "en")
            return formatter.string(from: date)
        }
    }

    // Placeholder for weight (not stored as a daily model but in UserProfile)
    private func weightForDate(_ date: Date) -> Double? {
        // Weight is stored as a single UserProfile value, not historically
        // Return nil unless UserProfile gets date-stamped entries
        nil
    }

    private func stepsForDate(_ date: Date) -> Int? {
        nil // Steps come from HealthKit live, not stored historically
    }

    private func sleepForDate(_ date: Date) -> SleepEntry? {
        sleepEntries.first { calendar.startOfDay(for: $0.date) == date }
    }

    private func dietForDate(_ date: Date) -> [DietEntry] {
        dietEntries.filter { calendar.startOfDay(for: $0.date) == date }
    }

    private func moodForDate(_ date: Date) -> MoodEntry? {
        moodEntries.first { calendar.startOfDay(for: $0.date) == date }
    }

    // MARK: Rows

    private func weightRow(weight: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "scalemass.fill")
                .foregroundStyle(.green)
                .frame(width: 20)
            Text(L10n.weightLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f kg", weight))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func stepsRow(steps: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(L10n.stepsLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(steps)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func sleepRow(_ entry: SleepEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.indigo)
                .frame(width: 20)
            Text(L10n.sleep)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f h", entry.hoursSlept))
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let comment = entry.qualityComment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dietRows(_ entries: [DietEntry]) -> some View {
        ForEach(entries) { entry in
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                Text(L10n.diet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.mealText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let cal = entry.estimatedCalories {
                        Text("~\(cal) kcal")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func moodRow(_ entry: MoodEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "face.smiling")
                .foregroundStyle(.pink)
                .frame(width: 20)
            Text(L10n.mood)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(entry.emoji)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HealthHistoryView()
}
