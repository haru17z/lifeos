import SwiftUI
import SwiftData
import AVFoundation

// MARK: - ScheduleView

struct ScheduleView: View {

    @Query(sort: \LifeTask.targetDate) private var tasks: [LifeTask]
    @Query private var holdings: [Holding]
    @Environment(\.modelContext) private var modelContext
    @Environment(IntentRouter.self) private var router

    @State private var selectedLocation: String?
    @State private var showMapSheet = false
    @State private var selectedTask: LifeTask?
    @State private var pendingReviewWrapper: PendingReviewWrapper?

    // AI Input
    @FocusState private var isInputFocused: Bool
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var clarifyMessage: String?
    @State private var showClarifyAlert = false
    @State private var isAiOffline = false

    // Manual task entry (fallback when AI is offline)
    @State private var showManualEntry = false
    @State private var manualTitle = ""
    @State private var manualTaskType: TaskType = .general

    // Edit mode & batch selection
    @State private var isEditing = false
    @State private var selectedTaskIds: Set<UUID> = []
    @State private var showDeleteAllConfirmation = false
    @State private var showHistory = false

    // Filter to today and future only for the main view
    private var todayAndFutureTasks: [LifeTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date.now)
        return tasks.filter { $0.targetDate >= startOfToday }
    }

    private var isChineseLocale: Bool {
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        return lang == "zh-Hans"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if isAiOffline {
                    aiOfflineBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if tasks.isEmpty {
                    emptyState
                } else {
                    timelineList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
        .safeAreaInset(edge: .bottom) {
            glassInputBar
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
        }
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
        .sheet(item: $pendingReviewWrapper) { wrapper in
            PendingReviewSheet(task: wrapper.task) {
                pendingReviewWrapper = nil
            }
        }
        .sheet(isPresented: $showManualEntry) {
            manualTaskEntrySheet
        }
        .sheet(isPresented: $showHistory) {
            ScheduleHistoryView()
        }
        .alert(L10n.clarificationNeeded, isPresented: $showClarifyAlert) {
            Button(L10n.ok) {}
        } message: {
            Text(clarifyMessage ?? L10n.provideDetails)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isAiOffline)
        .onAppear {
            NotificationManager.shared.onReviewRequested = { taskId in
                if let task = tasks.first(where: { $0.id == taskId }) {
                    pendingReviewWrapper = PendingReviewWrapper(id: task.id, task: task)
                }
            }
            checkOverdueTasks()
        }
    }

    // MARK: Glass Input Bar (safeAreaInset)

    private var glassInputBar: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .padding(.leading, 4)
            }

            TextField(L10n.inputPlaceholder, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .onSubmit(submitTask)

            Button(action: submitTask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color(.tertiaryLabel)
                            : Color.indigo
                    )
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: AI Offline Banner

    private var aiOfflineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(isChineseLocale ? "AI 离线 — 您仍可手动管理任务" : "AI Offline — You can still manage tasks manually")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showManualEntry = true
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(minWidth: 44, minHeight: 44)
            }
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isAiOffline = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.orange.opacity(0.2)), alignment: .bottom)
    }

    // MARK: Manual Task Entry Sheet

    private var manualTaskEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isChineseLocale ? "任务名称" : "Task Title", text: $manualTitle)
                    Picker(isChineseLocale ? "类型" : "Type", selection: $manualTaskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }
                Section {
                    Button {
                        let task = LifeTask(
                            title: manualTitle,
                            timeDisplay: L10n.today,
                            taskType: manualTaskType
                        )
                        modelContext.insert(task)
                        try? modelContext.save()
                        manualTitle = ""
                        showManualEntry = false
                    } label: {
                        Text(isChineseLocale ? "添加任务" : "Add Task")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(manualTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(isChineseLocale ? "手动添加" : "Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { showManualEntry = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: AI Submission

    private func submitTask() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true

        Task {
            do {
                let result = try await router.process(
                    input: text,
                    modelContext: modelContext,
                    tasks: tasks,
                    holdings: holdings
                )

                await MainActor.run {
                    if let question = result.clarifyQuestion {
                        clarifyMessage = question
                        showClarifyAlert = true
                    }

                    // Schedule notifications only for precise-time tasks (Spec 2b)
                    let allTasks = (try? modelContext.fetch(FetchDescriptor<LifeTask>())) ?? []
                    for id in result.createdTaskIds {
                        if let task = allTasks.first(where: { $0.id == id }),
                           task.isExactTime {
                            NotificationManager.shared.scheduleNotification(for: task)
                        }
                    }
                    // Re-schedule for updated tasks
                    for id in result.updatedTaskIds {
                        NotificationManager.shared.cancelNotification(for: id)
                        if let task = allTasks.first(where: { $0.id == id }),
                           task.isExactTime {
                            NotificationManager.shared.scheduleNotification(for: task)
                        }
                    }
                    // Cancel for deleted
                    for id in result.deletedTaskIds {
                        NotificationManager.shared.cancelNotification(for: id)
                    }

                    inputText = ""
                    if isAiOffline { isAiOffline = false }
                }
            } catch {
                print("[ScheduleView] AI PARSE ERROR: \(error)")
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isAiOffline = true
                    }
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }

    // MARK: Overdue Check

    private func checkOverdueTasks() {
        let now = Date.now
        let overdue = tasks.filter {
            !$0.isCompleted
            && $0.startTime < now
            && Calendar.current.startOfDay(for: $0.targetDate) <= Calendar.current.startOfDay(for: now)
        }
        if let first = overdue.first {
            pendingReviewWrapper = PendingReviewWrapper(id: first.id, task: first)
        }
    }

    // MARK: Grouped Tasks

    private var groupedTasks: [(date: Date, tasks: [LifeTask])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: todayAndFutureTasks) { task in
            calendar.startOfDay(for: task.targetDate)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, tasks: $0.value.sorted { ($0.startTime) < ($1.startTime) }) }
    }

    // MARK: Timeline List

    private var timelineList: some View {
        VStack(spacing: 0) {
            // Edit mode header
            editModeHeader

            List {
                ForEach(groupedTasks, id: \.date) { group in
                    let pending = group.tasks.filter { !$0.isCompleted }
                    let completed = group.tasks.filter { $0.isCompleted }

                    Section {
                        ForEach(pending) { task in
                            taskRow(task)
                        }

                        if !completed.isEmpty {
                            DisclosureGroup {
                                ForEach(completed) { task in
                                    taskRow(task)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.caption)
                                    Text("\(L10n.completed) (\(completed.count))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.secondary)
                            }
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

            // Batch action bar
            if isEditing {
                batchActionBar
            }
        }
    }

    // MARK: Edit Mode Header

    private var editModeHeader: some View {
        HStack {
            Button {
                showHistory = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline)
                    Text(language == "zh-Hans" ? "历史" : "History")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isEditing.toggle()
                    if !isEditing { selectedTaskIds.removeAll() }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "checklist")
                        .font(.subheadline)
                    Text(isEditing
                         ? (language == "zh-Hans" ? "完成" : "Done")
                         : (language == "zh-Hans" ? "选择" : "Select"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(isEditing ? Color.green : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var language: String {
        UserDefaults.standard.string(forKey: "language") ?? "en"
    }

    // MARK: Batch Action Bar

    private var batchActionBar: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                deleteSelectedTasks()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text(language == "zh-Hans"
                         ? "删除所选 (\(selectedTaskIds.count))"
                         : "Delete Selected (\(selectedTaskIds.count))")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }
            .disabled(selectedTaskIds.isEmpty)

            Spacer()

            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text(language == "zh-Hans" ? "删除全部" : "Delete All")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .top)
        .alert(language == "zh-Hans" ? "删除全部任务？" : "Delete All Tasks?",
               isPresented: $showDeleteAllConfirmation) {
            Button(language == "zh-Hans" ? "取消" : "Cancel", role: .cancel) {}
            Button(language == "zh-Hans" ? "全部删除" : "Delete All", role: .destructive) {
                deleteAllTasks()
            }
        } message: {
            Text(language == "zh-Hans"
                 ? "此操作将永久删除所有任务，无法撤销。"
                 : "This will permanently delete all tasks. This cannot be undone.")
        }
    }

    private func taskRow(_ task: LifeTask) -> some View {
        HStack(spacing: 0) {
            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        if selectedTaskIds.contains(task.id) {
                            selectedTaskIds.remove(task.id)
                        } else {
                            selectedTaskIds.insert(task.id)
                        }
                    }
                } label: {
                    Image(systemName: selectedTaskIds.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedTaskIds.contains(task.id) ? .blue : .gray.opacity(0.4))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            Button {
                if isEditing {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        if selectedTaskIds.contains(task.id) {
                            selectedTaskIds.remove(task.id)
                        } else {
                            selectedTaskIds.insert(task.id)
                        }
                    }
                } else {
                    selectedTask = task
                }
            } label: {
                TaskCardView(task: task, onLocationTap: { location in
                    selectedLocation = location
                    showMapSheet = true
                })
                .strikethrough(task.isCompleted)
                .opacity(task.isCompleted ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .onLongPressGesture(minimumDuration: 0.5) {
                if !isEditing {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isEditing = true
                        selectedTaskIds.insert(task.id)
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: isEditing ? 4 : 16, bottom: 2, trailing: 16))
    }

    private func sectionHeaderText(for date: Date) -> String {
        let calendar = Calendar.current
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        let isChinese = lang == "zh-Hans"

        if calendar.isDateInToday(date) {
            return L10n.today
        } else if calendar.isDateInTomorrow(date) {
            return L10n.tomorrow
        } else if calendar.isDateInYesterday(date) {
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
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.noTasks)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(L10n.getStarted)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func deleteSelectedTasks() {
        let ids = selectedTaskIds
        guard !ids.isEmpty else { return }

        for task in tasks where ids.contains(task.id) {
            NotificationManager.shared.cancelNotification(for: task.id)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            for task in tasks where ids.contains(task.id) {
                modelContext.delete(task)
            }
            try? modelContext.save()
            selectedTaskIds.removeAll()
            if tasks.isEmpty { isEditing = false }
        }
    }

    private func deleteAllTasks() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            for task in tasks {
                NotificationManager.shared.cancelNotification(for: task.id)
                modelContext.delete(task)
            }
            try? modelContext.save()
            selectedTaskIds.removeAll()
            isEditing = false
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

    @AppStorage("language") private var language = "en"
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
    @State private var beepPulse = false

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

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.titleLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        TextField(L10n.taskTitlePlaceholder, text: $editedTitle)
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.timeLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if editedIsExactTime {
                            VStack(spacing: 12) {
                                HStack {
                                    Text(L10n.start)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    DatePicker("", selection: $editedExactStart, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.wheel)
                                        .frame(height: 120)
                                }
                                HStack {
                                    Text(L10n.timeEnd)
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
                                TextField(L10n.timeDisplayPlaceholder, text: $editedTimeDisplay)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let location = task.location, !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.subheadline)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if task.taskType == .study {
                        studyModule
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
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
                    triggerRandomPromptAlert()
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

            sectionHeader(L10n.focusSession, icon: "brain.head.profile")

            Picker(L10n.methodLabel, selection: $studyMethod) {
                ForEach(StudyMethod.allCases, id: \.self) { method in
                    Text(method == .pomodoro ? L10n.pomodoroMethod : L10n.randomPromptMethod)
                        .tag(method)
                }
            }
            .pickerStyle(.segmented)
            .id(language)

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
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(width: 200, height: 200)

            HStack(spacing: 20) {
                Button(isPomodoroRunning ? L10n.pause : L10n.start) {
                    isPomodoroRunning ? pausePomodoro() : startPomodoro()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(L10n.reset) {
                    resetPomodoro()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var randomBeepView: some View {
        VStack(spacing: 16) {
            Text(L10n.randomPromptDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(isBeepSessionActive ? L10n.endSession : L10n.startSession) {
                isBeepSessionActive ? stopBeepSession() : startBeepSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(isBeepSessionActive ? Color.red : Color.blue)
            .controlSize(.large)

            if isBeepSessionActive {
                HStack(spacing: 8) {
                    // Minimal industrial pulse indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(beepPulse ? 1.8 : 0.6)
                        .opacity(beepPulse ? 0.4 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                beepPulse = true
                            }
                        }
                        .onDisappear { beepPulse = false }

                    Text(L10n.sessionActiveHint)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func startPomodoro() { isPomodoroRunning = true }
    private func pausePomodoro() { isPomodoroRunning = false }
    private func resetPomodoro() {
        isPomodoroRunning = false
        pomodoroRemaining = pomodoroTotal
    }
    private func stopPomodoroTimer() { isPomodoroRunning = false }

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

    /// Plays an alert for the Random Prompt session.
    /// Respects the hardware mute switch: uses haptics when muted, audio otherwise.
    private func triggerRandomPromptAlert() {
        let audioSession = AVAudioSession.sharedInstance()
        let isMuted = audioSession.outputVolume <= 0.01

        if isMuted {
            // Hardware mute switch engaged — use haptics only
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            // Secondary tap for emphasis
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            AudioServicesPlaySystemSound(1304)
        }
    }

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

// MARK: - PendingReviewSheet

struct PendingReviewSheet: View {
    let task: LifeTask
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var completionRate: Double = 50
    @State private var excuseNote: String = ""
    @State private var isSubmitting = false
    @State private var newTargetDate: Date
    @State private var isEasyStarting = false
    @State private var isRescheduling = false

    init(task: LifeTask, onDismiss: @escaping () -> Void) {
        self.task = task
        self.onDismiss = onDismiss
        _newTargetDate = State(initialValue: task.targetDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                        .padding(.top, 20)

                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(L10n.reviewScheduledPrompt(task.timeDisplay))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        HStack {
                            Text(L10n.completionRateLabel)
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
                    .background(Color(UIColor.secondarySystemGroupedBackground))
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.reschedule)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        DatePicker(L10n.newDate, selection: $newTargetDate, displayedComponents: .date)
                            .datePickerStyle(.compact)

                        Button {
                            isRescheduling = true
                            task.targetDate = Calendar.current.startOfDay(for: newTargetDate)
                            try? modelContext.save()
                            onDismiss()
                        } label: {
                            Text(L10n.rescheduleTask)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 10) {
                        Text(L10n.tryEasyStart)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            isEasyStarting = true
                            Task {
                                do {
                                    let steps = try await AIManager().microStepBreakdown(task: task)
                                    await MainActor.run {
                                        for step in steps {
                                            let microTask = LifeTask(
                                                title: step,
                                                startTime: task.startTime,
                                                targetDate: task.targetDate,
                                                timeDisplay: task.timeDisplay,
                                                taskType: task.taskType
                                            )
                                            modelContext.insert(microTask)
                                        }
                                        try? modelContext.save()
                                        isEasyStarting = false
                                        onDismiss()
                                    }
                                } catch {
                                    await MainActor.run {
                                        isEasyStarting = false
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isEasyStarting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                }
                                Image(systemName: "sparkles")
                                Text(isEasyStarting ? L10n.breakingDown : L10n.easyStart)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(isEasyStarting)
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
                            Text(L10n.submitToAI)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button(L10n.close) {
                        onDismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .navigationTitle(L10n.taskReview)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - PendingReviewWrapper

struct PendingReviewWrapper: Identifiable {
    let id: UUID
    let task: LifeTask
}
