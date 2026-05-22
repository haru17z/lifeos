import WidgetKit
import SwiftUI

// MARK: - Shared UserDefaults

enum WidgetData {
    static let suiteName = "group.com.lifeos.app"
    static let isActiveKey = "widget_focus_active"
    static let isBreakKey = "widget_is_break"
    static let setsTotalKey = "widget_sets_total"
    static let setsCurrentKey = "widget_sets_current"
    static let secondsRemainingKey = "widget_seconds_remaining"
    static let methodKey = "widget_method"
    static let studyContentKey = "widget_study_content"
    static let lastUpdateKey = "widget_last_update"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

// MARK: - FocusEntry

struct FocusEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let isBreak: Bool
    let setsTotal: Int
    let setsCurrent: Int
    let secondsRemaining: Int
    let method: String
    let studyContent: String?
}

// MARK: - Provider

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(
            date: Date(),
            isActive: false,
            isBreak: false,
            setsTotal: 4,
            setsCurrent: 1,
            secondsRemaining: 1500,
            method: "pomodoro",
            studyContent: "Focus Session"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        let entry = currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: entry.isActive ? 15 : 300, to: Date()) ?? Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> FocusEntry {
        let defaults = WidgetData.sharedDefaults
        let lastUpdate = defaults.double(forKey: WidgetData.lastUpdateKey)
        let storedSeconds = defaults.integer(forKey: WidgetData.secondsRemainingKey)
        let isActive = defaults.bool(forKey: WidgetData.isActiveKey)
        let secondsElapsed = lastUpdate > 0 ? Int(Date().timeIntervalSince1970 - lastUpdate) : 0

        return FocusEntry(
            date: Date(),
            isActive: isActive,
            isBreak: defaults.bool(forKey: WidgetData.isBreakKey),
            setsTotal: max(1, defaults.integer(forKey: WidgetData.setsTotalKey)),
            setsCurrent: max(1, defaults.integer(forKey: WidgetData.setsCurrentKey)),
            secondsRemaining: isActive ? max(0, storedSeconds - secondsElapsed) : storedSeconds,
            method: defaults.string(forKey: WidgetData.methodKey) ?? "pomodoro",
            studyContent: defaults.string(forKey: WidgetData.studyContentKey)
        )
    }
}

// MARK: - Widget View

struct FocusWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FocusEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .accessoryCircular:
            circularAccessory
        case .accessoryRectangular:
            rectangularAccessory
        default:
            mediumWidget
        }
    }

    // MARK: Small Widget

    private var smallWidget: some View {
        VStack(spacing: 8) {
            // Timer ring
            ZStack {
                Circle()
                    .stroke(entry.isBreak ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(entry.isBreak ? Color.orange : Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(timeString(from: entry.secondsRemaining))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(entry.isActive ? (entry.isBreak ? "Break" : "Focus") : "Ready")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Set dots
            HStack(spacing: 3) {
                ForEach(1...min(entry.setsTotal, 8), id: \.self) { set in
                    Circle()
                        .fill(setDotColor(for: set))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    // MARK: Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 20) {
            // Timer ring
            ZStack {
                Circle()
                    .stroke(entry.isBreak ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(entry.isBreak ? Color.orange : Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(timeString(from: entry.secondsRemaining))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(entry.isActive ? (entry.isBreak ? "Break" : "Focus") : "Ready")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.method == "pomodoro" ? "Pomodoro" : "Random Prompt")
                    .font(.headline)
                    .fontWeight(.bold)

                if let content = entry.studyContent, !content.isEmpty {
                    Text(content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    ForEach(1...min(entry.setsTotal, 8), id: \.self) { set in
                        Circle()
                            .fill(setDotColor(for: set))
                            .frame(width: 7, height: 7)
                    }
                }

                Text("Set \(entry.setsCurrent) of \(entry.setsTotal)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    // MARK: Accessory Circular

    private var circularAccessory: some View {
        ZStack {
            Circle()
                .stroke(entry.isBreak ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(entry.isBreak ? Color.orange : Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(timeStringShort(from: entry.secondsRemaining))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(entry.setsCurrent)/\(entry.setsTotal)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: Accessory Rectangular

    private var rectangularAccessory: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.method == "pomodoro" ? "Pomodoro" : "Random Prompt")
                    .font(.headline)
                Text(timeString(from: entry.secondsRemaining))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("Set \(entry.setsCurrent)/\(entry.setsTotal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: Helpers

    private var progressValue: Double {
        guard entry.isActive else { return 0 }
        let total = entry.isBreak ? 300.0 : 1500.0
        return max(0, min(1, Double(entry.secondsRemaining) / total))
    }

    private func setDotColor(for set: Int) -> Color {
        if set < entry.setsCurrent { return .green }
        if set == entry.setsCurrent {
            if entry.isBreak { return .orange }
            if entry.isActive { return .blue }
            return .blue.opacity(0.4)
        }
        return .gray.opacity(0.3)
    }

    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func timeStringShort(from seconds: Int) -> String {
        let m = seconds / 60
        return "\(m)m"
    }
}

// MARK: - Widget Definition

struct FocusWidget: Widget {
    let kind = "com.lifeos.focuswidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Timer")
        .description("Monitor your Pomodoro and Random Prompt sessions at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
