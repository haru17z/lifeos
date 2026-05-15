import SwiftUI
import SwiftData
import AVFoundation

// MARK: - ScheduleView

struct ScheduleView: View {

    @Query(sort: \LifeTask.targetDate) private var tasks: [LifeTask]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLocation: String?
    @State private var showMapSheet = false
    @State private var selectedTask: LifeTask?
    @State private var showPendingReview = false
    @State private var pendingReviewTask: LifeTask?

    var body: some View {
        VStack(spacing: 0) {
            if tasks.isEmpty {
                emptyState
            } else {
                timelineList
            }
        }
        .background(Color(.systemBackground))
        .confirmationDialog(L10n.navigateWith, isPresented: $showMapSheet, presenting: selectedLocation) { location in
            Button("Amap (高德)") { openMapScheme("iosamap://path?name=\(location)") }
            Button("Baidu (百度)") { openMapScheme("baidumap://map/geocoder?address=\(location)") }
            Button("Tencent (腾讯)") { openMapScheme("qqmap://map/search?keyword=\(location)") }
            Button(L10n.appleMaps) { openAppleMaps(location: location) }
            Button(L10n.cancel, role: .cancel) {}
        } message: { location in
            Text("Open \"\(location)\" in:")
        }
        .sheet(item: $selectedTask) { task in
            TaskEditSheet(task: task)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPendingReview) {
            if let task = pendingReviewTask {
                PendingReviewSheet(task: task) {
                    showPendingReview = false
                    pendingReviewTask = nil
                }
            }
        }
        .onAppear {
            NotificationManager.shared.onReviewRequested = { taskId in
                if let task = tasks.first(where: { $0.id == taskId }) {
                    pendingReviewTask = task
                    showPendingReview = true
                }
            }
            checkOverdueTasks()
        }
    }

    // MARK: Overdue Check

    private func checkOverdueTasks() {
        let now = Date.now
        // Find tasks whose startTime has passed, not yet completed, and due today or earlier
        let overdue = tasks.filter {
            !$0.isCompleted
            && $0.startTime < now
            && Calendar.current.startOfDay(for: $0.targetDate) <= Calendar.current.startOfDay(for: now)
        }
        if let first = overdue.first {
            pendingReviewTask = first
            showPendingReview = true
        }
    }

    // MARK: Grouped Tasks

    private var groupedTasks: [(date: Date, tasks: [LifeTask])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: tasks) { task in
            calendar.startOfDay(for: task.targetDate)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, tasks: $0.value.sorted { ($0.startTime) < ($1.startTime) }) }
    }

    // MARK: Timeline List

    private var timelineList: some View {
        List {
            ForEach(groupedTasks, id: \.date) { group in
                Section {
                    ForEach(group.tasks) { task in
                        Button {
                            selectedTask = task
                        } label: {
                            TaskCardView(task: task, onLocationTap: { location in
                                selectedLocation = location
                                showMapSheet = true
                            })
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteSingleTask(task)
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                } header: {
                    Text(sectionHeaderText(for: group.date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tasks.count)
    }

    private func sectionHeaderText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.today
        } else if calendar.isDateInTomorrow(date) {
            return L10n.tomorrow
        } else if calendar.isDate(date, equalTo: Date.now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.noTasks)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(L10n.getStarted)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func deleteSingleTask(_ task: LifeTask) {
        NotificationManager.shared.cancelNotification(for: task.id)
        withAnimation {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }

    // MARK: Map Helpers

    private func openMapScheme(_ urlString: String) {
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else { return }
        UIApplication.shared.open(url)
    }

    private func openAppleMaps(location: String) {
        guard let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - TaskEditSheet (Editable Half-Sheet)

struct TaskEditSheet: View {
    let task: LifeTask
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String
    @State private var editedTimeDisplay: String
    @State private var editedIsExactTime: Bool
    @State private var editedExactStart: Date
    @State private var editedExactEnd: Date

    // Pomodoro
    @State private var studyMethod: StudyMethod = .pomodoro
    @State private var pomodoroRemaining: Int = 1500
    @State private var isPomodoroRunning = false

    // Random Beep
    @State private var beepTargetSeconds: Int = 0
    @State private var beepElapsed: Int = 0
    @State private var isBeepSessionActive = false

    private let pomodoroTotal: Int = 1500

    enum StudyMethod: String, CaseIterable {
        case pomodoro = "Pomodoro"
        case randomBeep = "Random Beep"
    }

    init(task: LifeTask) {
        self.task = task
        _editedTitle = State(initialValue: task.title)
        _editedTimeDisplay = State(initialValue: task.timeDisplay)
        _editedIsExactTime = State(initialValue: task.isExactTime)
        _editedExactStart = State(initialValue: task.exactStartTime ?? task.startTime)
        _editedExactEnd = State(initialValue: task.exactEndTime ?? task.endTime ?? task.startTime.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type badge + completion
                    HStack {
                        Label(task.taskType.rawValue.capitalized, systemImage: taskTypeIcon)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(taskTypeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(taskTypeColor.opacity(0.15))
                            .clipShape(Capsule())

                        Spacer()

                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? Color.green : Color(.tertiaryLabel))
                            .font(.title3)
                    }

                    // Editable Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        TextField("Task title", text: $editedTitle)
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    // Editable Time — exact vs fuzzy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if editedIsExactTime {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Start")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    DatePicker("", selection: $editedExactStart, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.wheel)
                                        .frame(height: 120)
                                }
                                HStack {
                                    Text("End")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    DatePicker("", selection: $editedExactEnd, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.wheel)
                                        .frame(height: 120)
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.subheadline)
                                TextField("e.g. Morning, 8:00 AM", text: $editedTimeDisplay)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Location (read-only)
                    if let location = task.location, !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.subheadline)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // ── Study Module (Pomodoro + Random Beep) ──
                    if task.taskType == .study {
                        studyModule
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.task)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        stopPomodoroTimer()
                        stopBeepSession()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        task.title = editedTitle
                        task.timeDisplay = editedTimeDisplay
                        task.isExactTime = editedIsExactTime
                        task.exactStartTime = editedIsExactTime ? editedExactStart : nil
                        task.exactEndTime = editedIsExactTime ? editedExactEnd : nil
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if isPomodoroRunning && pomodoroRemaining > 0 {
                    pomodoroRemaining -= 1
                }
                guard isBeepSessionActive else { return }
                beepElapsed += 1
                if beepElapsed >= beepTargetSeconds {
                    AudioServicesPlaySystemSound(1304)
                    beepElapsed = 0
                    beepTargetSeconds = Int.random(in: 60...300)
                }
            }
            .onDisappear {
                stopPomodoroTimer()
                stopBeepSession()
            }
        }
    }

    // MARK: Study Module

    private var studyModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.vertical, 4)

            sectionHeader("Focus Session", icon: "brain.head.profile")

            Picker("Method", selection: $studyMethod) {
                ForEach(StudyMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)

            switch studyMethod {
            case .pomodoro:
                pomodoroView
            case .randomBeep:
                randomBeepView
            }
        }
    }

    private var pomodoroView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(pomodoroRemaining) / CGFloat(pomodoroTotal))
                    .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: pomodoroRemaining)

                Text(timeString(from: pomodoroRemaining))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 200, height: 200)

            HStack(spacing: 20) {
                Button(isPomodoroRunning ? "Pause" : "Start") {
                    isPomodoroRunning ? pausePomodoro() : startPomodoro()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Reset") {
                    resetPomodoro()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var randomBeepView: some View {
        VStack(spacing: 16) {
            Text("Plays a sound at random intervals (1-5 min) to check your focus. Start a session and the app will alert you at unpredictable moments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(isBeepSessionActive ? "End Session" : "Start Session") {
                isBeepSessionActive ? stopBeepSession() : startBeepSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(isBeepSessionActive ? Color.red : Color.blue)
            .controlSize(.large)

            if isBeepSessionActive {
                Text("Session active — next beep at a random interval")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Pomodoro Logic

    private func startPomodoro() { isPomodoroRunning = true }
    private func pausePomodoro() { isPomodoroRunning = false }
    private func resetPomodoro() {
        isPomodoroRunning = false
        pomodoroRemaining = pomodoroTotal
    }
    private func stopPomodoroTimer() { isPomodoroRunning = false }

    // MARK: Random Beep Logic

    private func startBeepSession() {
        isBeepSessionActive = true
        beepElapsed = 0
        beepTargetSeconds = Int.random(in: 60...300)
    }
    private func stopBeepSession() {
        isBeepSessionActive = false
        beepElapsed = 0
        beepTargetSeconds = 0
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(taskTypeColor)
            Text(title)
                .font(.headline)
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

    private var taskTypeIcon: String {
        switch task.taskType {
        case .study:    return "brain.head.profile"
        case .health:   return "heart.fill"
        case .finance:  return "chart.pie.fill"
        case .vision:   return "eye.fill"
        case .general:  return "square.stack.fill"
        }
    }

    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - PendingReviewSheet (Deadline Review Popup)

struct PendingReviewSheet: View {
    let task: LifeTask
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var completionRate: Double = 50
    @State private var excuseNote: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "hourglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text(task.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("This task was scheduled for \(task.timeDisplay). How did it go?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    HStack {
                        Text("Completion")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(completionRate))%")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    Slider(value: $completionRate, in: 0...100, step: 5)
                        .tint(completionRate > 50 ? .green : .orange)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.thoughtsExcuses)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField(L10n.howDidItGo, text: $excuseNote, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .lineLimit(2...4)
                }

                Button {
                    isSubmitting = true
                    task.isCompleted = true
                    try? modelContext.save()
                    onDismiss()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Submit Review")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button("Skip") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Task Review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
