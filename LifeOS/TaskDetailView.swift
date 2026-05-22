import SwiftUI
import Charts
import AVFoundation
import SwiftData

// MARK: - TaskDetailView

struct TaskDetailView: View {
    let task: LifeTask
    @Environment(\.modelContext) private var modelContext
    @AppStorage("language") private var language = "en"

    // MARK: Feedback State
    @State private var completionRate: Double = 50
    @State private var feedbackNote: String = ""
    @State private var isSubmittingFeedback = false
    @State private var aiCoachResponse: String?
    @State private var feedbackError: String?

    // MARK: Study State
    @State private var studyMethod: StudyMethod = .pomodoro
    @State private var numberOfSets: Int = 2
    @State private var learningMinutes: Int = 60
    @State private var numberOfSetsText: String = "2"
    @State private var learningMinutesText: String = "60"
    @FocusState private var isSetsFocused: Bool
    @FocusState private var isDurationFocused: Bool
    @State private var currentSet: Int = 1
    @State private var isFocusActive = false
    @State private var isBreakActive = false
    @State private var focusSecondsRemaining: Int = 1500
    @State private var breakSecondsRemaining: Int = 300
    @State private var studyContent: String = ""

    // Random Prompt
    @State private var beepTargetSeconds: Int = 0
    @State private var beepElapsed: Int = 0
    @State private var isBeepSessionActive = false
    @State private var currentPrompt: String?
    @State private var showPrompt = false

    // Session tracking
    @State private var sessionStartDate: Date?
    @State private var sessionElapsedSeconds: Int = 0
    @State private var showSessionComplete = false
    @State private var widgetSyncTick: Int = 0

    // MARK: Health State
    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var fastStart = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var fastEnd = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var foodLog: String = ""

    // MARK: Finance State
    @State private var dcaAmount: String = ""

    private let focusDuration: Int = 1500
    private let breakDuration: Int = 300

    private let learningPrompts = [
        "Take a deep breath. What's the one key insight so far?",
        "Explain what you just learned to an imaginary student.",
        "What question would you ask to test your understanding?",
        "Connect this to something you already know.",
        "If you had to teach this in 60 seconds, what would you say?",
        "What's the most surprising thing you've learned?",
        "How would you apply this knowledge tomorrow?",
        "Pause. What gap in your understanding needs filling?"
    ]

    enum StudyMethod: String, CaseIterable {
        case pomodoro = "Pomodoro"
        case randomBeep = "Random Prompt"
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header Card
                headerCard

                // Module Section
                switch task.taskType {
                case .study:    studyModule
                case .health:   healthModule
                case .finance:  financeModule
                case .vision:   visionModule
                case .general:  generalModule
                }

                Divider()

                // Feedback Section
                feedbackSection
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .contentShape(Rectangle())
        .dismissKeyboardOnTap()
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showPrompt, let prompt = currentPrompt {
                promptOverlay(prompt)
            }
        }
        .overlay {
            if showSessionComplete {
                sessionCompleteOverlay
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            timerTick()
        }
        .onDisappear {
            stopAllTimers()
        }
        .onAppear {
            if task.taskType == .study, task.pomodoroSets > 0 {
                numberOfSets = task.pomodoroSets
                numberOfSetsText = String(task.pomodoroSets)
                learningMinutes = task.pomodoroSets * 30
                learningMinutesText = String(learningMinutes)
            }
        }
    }

    // MARK: - Timer Logic

    private func timerTick() {
        // Pomodoro focus countdown
        if isFocusActive && focusSecondsRemaining > 0 {
            focusSecondsRemaining -= 1
            sessionElapsedSeconds += 1

            if focusSecondsRemaining == 0 {
                focusSetComplete()
            }
        }

        // Break countdown
        if isBreakActive && breakSecondsRemaining > 0 {
            breakSecondsRemaining -= 1

            if breakSecondsRemaining == 0 {
                breakComplete()
            }
        }

        // Random Beep tick
        if isBeepSessionActive {
            beepElapsed += 1
            sessionElapsedSeconds += 1
            if beepElapsed >= beepTargetSeconds {
                triggerRandomPrompt()
                beepElapsed = 0
                beepTargetSeconds = Int.random(in: 60...300)
            }
        }

        // Sync widget every 5 ticks
        widgetSyncTick += 1
        if widgetSyncTick >= 5 {
            widgetSyncTick = 0
            syncWidgetState()
        }
    }

    private func focusSetComplete() {
        AudioServicesPlaySystemSound(1026)
        isFocusActive = false

        if currentSet < numberOfSets {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                currentPrompt = learningPrompts.randomElement()
                showPrompt = true
            }
            isBreakActive = true
            breakSecondsRemaining = breakDuration
        } else {
            completeSession()
        }
    }

    private func breakComplete() {
        AudioServicesPlaySystemSound(1027)
        isBreakActive = false
        showPrompt = false
        currentSet += 1
        focusSecondsRemaining = focusDuration
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFocusActive = true
        }
    }

    private func triggerRandomPrompt() {
        AudioServicesPlaySystemSound(1304)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentPrompt = learningPrompts.randomElement()
            showPrompt = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if showPrompt {
                    showPrompt = false
                }
            }
        }
    }

    private func completeSession() {
        isFocusActive = false
        isBreakActive = false
        let session = FocusSession(
            date: sessionStartDate ?? Date.now,
            durationSeconds: sessionElapsedSeconds,
            method: studyMethod == .pomodoro ? "pomodoro" : "randomPrompt",
            setsCompleted: currentSet,
            totalSets: numberOfSets,
            studyContent: studyContent.isEmpty ? nil : studyContent
        )
        modelContext.insert(session)
        try? modelContext.save()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showSessionComplete = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSessionComplete = false
            }
        }
    }

    private func stopAllTimers() {
        isFocusActive = false
        isBreakActive = false
        isBeepSessionActive = false
        showPrompt = false
        WidgetDataSync.clear()
    }

    private func syncWidgetState() {
        let seconds = isBreakActive ? breakSecondsRemaining : focusSecondsRemaining
        WidgetDataSync.update(
            isActive: isFocusActive || isBreakActive || isBeepSessionActive,
            isBreak: isBreakActive,
            setsTotal: numberOfSets,
            setsCurrent: currentSet,
            secondsRemaining: seconds,
            method: studyMethod == .pomodoro ? "pomodoro" : "randomPrompt",
            studyContent: studyContent.isEmpty ? nil : studyContent
        )
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.taskType.rawValue.capitalized)
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

            Text(task.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(task.timeDisplay)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let location = task.location, !location.isEmpty {
                    Label(location, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let notes = task.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.taskNotes)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Study Module

    private var studyModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(L10n.focusSession, icon: "brain.head.profile")

            Picker(L10n.methodLabel, selection: $studyMethod) {
                ForEach(StudyMethod.allCases, id: \.self) { method in
                    Text(method == .pomodoro ? L10n.pomodoroMethod : L10n.randomPromptMethod)
                        .tag(method)
                }
            }
            .pickerStyle(.segmented)
            .id(language)

            // Sets Picker Wheel
            setsPicker

            switch studyMethod {
            case .pomodoro:
                pomodoroView
            case .randomBeep:
                randomPromptView
            }

            // Study Content Input
            studyContentInput
        }
    }

    // MARK: Sets & Duration Picker

    private var setsPicker: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L10n.setsLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        if numberOfSets > 1 { updateSets(numberOfSets - 1) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(numberOfSets > 1 && !(isFocusActive || isBreakActive) ? .blue : .gray.opacity(0.3))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(isFocusActive || isBreakActive || numberOfSets <= 1)

                    TextField("", text: $numberOfSetsText)
                        .keyboardType(.numberPad)
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .focused($isSetsFocused)
                        .disabled(isFocusActive || isBreakActive)
                        .onChange(of: isSetsFocused) { _, focused in
                            if !focused { commitSetsText() }
                        }

                    Button {
                        if numberOfSets < 32 { updateSets(numberOfSets + 1) }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(numberOfSets < 32 && !(isFocusActive || isBreakActive) ? .blue : .gray.opacity(0.3))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(isFocusActive || isBreakActive || numberOfSets >= 32)
                }
            }

            HStack {
                Text(L10n.learningDuration)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 6) {
                    TextField("", text: $learningMinutesText)
                        .keyboardType(.numberPad)
                        .font(.body)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(width: 80, alignment: .trailing)
                        .focused($isDurationFocused)
                        .disabled(isFocusActive || isBreakActive)
                        .onChange(of: isDurationFocused) { _, focused in
                            if !focused { commitDurationText() }
                        }
                    Text(L10n.minutesUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(L10n.setIndicator(currentSet, numberOfSets))
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(isFocusActive || isBreakActive ? 1 : 0.4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Sets/Duration sync helpers

    private func updateSets(_ newValue: Int) {
        let clamped = min(max(newValue, 1), 32)
        numberOfSets = clamped
        numberOfSetsText = String(clamped)
        learningMinutes = clamped * 30
        learningMinutesText = String(learningMinutes)
    }

    private func commitSetsText() {
        guard let parsed = Int(numberOfSetsText.trimmingCharacters(in: .whitespaces)) else {
            numberOfSetsText = String(numberOfSets)
            return
        }
        updateSets(parsed)
    }

    private func commitDurationText() {
        guard let parsed = Int(learningMinutesText.trimmingCharacters(in: .whitespaces)) else {
            learningMinutesText = String(learningMinutes)
            return
        }
        let clamped = min(max(parsed, 30), 960)
        learningMinutes = clamped
        learningMinutesText = String(clamped)
        numberOfSets = Int(ceil(Double(clamped) / 30.0))
        numberOfSetsText = String(numberOfSets)
    }

    // MARK: Pomodoro View

    private var pomodoroView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        isBreakActive ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15),
                        lineWidth: 8
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: isBreakActive
                        ? CGFloat(breakSecondsRemaining) / CGFloat(breakDuration)
                        : CGFloat(focusSecondsRemaining) / CGFloat(focusDuration)
                    )
                    .stroke(
                        isBreakActive ? Color.orange : Color.blue,
                        style: SwiftUI.StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: isBreakActive ? breakSecondsRemaining : focusSecondsRemaining)

                VStack(spacing: 4) {
                    Text(timeString(from: isBreakActive ? breakSecondsRemaining : focusSecondsRemaining))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text(isBreakActive ? L10n.breakLabel : L10n.focusLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isBreakActive ? .orange : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background((isBreakActive ? Color.orange : Color.blue).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 200, height: 200)

            // Set progress dots
            HStack(spacing: 6) {
                ForEach(1...numberOfSets, id: \.self) { set in
                    Circle()
                        .fill(setColor(for: set))
                        .frame(width: 10, height: 10)
                        .scaleEffect(set == currentSet && (isFocusActive || isBreakActive) ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentSet)
                }
            }

            HStack(spacing: 20) {
                Button {
                    if isFocusActive || isBreakActive {
                        pauseSession()
                    } else {
                        startSession()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isFocusActive || isBreakActive ? "pause.fill" : "play.fill")
                        Text(isFocusActive || isBreakActive ? L10n.pause : L10n.start)
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    resetSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L10n.reset)
                    }
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

    private func setColor(for set: Int) -> Color {
        if set < currentSet { return .green }
        if set == currentSet {
            if isBreakActive { return .orange }
            if isFocusActive { return .blue }
            return .blue.opacity(0.4)
        }
        return .gray.opacity(0.3)
    }

    // MARK: Random Prompt View

    private var randomPromptView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.indigo, .indigo.opacity(0.4), .indigo.opacity(0.2), .indigo.opacity(0.4)]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(isBeepSessionActive ? 360 : 0))
                        .animation(
                            isBeepSessionActive
                                ? .linear(duration: 4).repeatForever(autoreverses: false)
                                : .default,
                            value: isBeepSessionActive
                        )

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.indigo)
                }

                Text(L10n.randomPromptDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)

            Button {
                if isBeepSessionActive {
                    stopBeepSession()
                } else {
                    startBeepSession()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isBeepSessionActive ? "stop.fill" : "play.fill")
                    Text(isBeepSessionActive ? L10n.endSession : L10n.startSession)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isBeepSessionActive ? .red : .indigo)
            .controlSize(.large)

            if isBeepSessionActive {
                Text(L10n.sessionActiveHint)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Study Content Input

    private var studyContentInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.studyContentLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField(L10n.studyContentPlaceholder, text: $studyContent, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(2...5)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Session Actions

    private func startSession() {
        sessionStartDate = Date.now
        sessionElapsedSeconds = 0
        focusSecondsRemaining = focusDuration
        currentSet = 1
        widgetSyncTick = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFocusActive = true
        }
        syncWidgetState()
    }

    private func pauseSession() {
        isFocusActive = false
        isBreakActive = false
        syncWidgetState()
    }

    private func resetSession() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFocusActive = false
            isBreakActive = false
        }
        focusSecondsRemaining = focusDuration
        breakSecondsRemaining = breakDuration
        currentSet = 1
        sessionElapsedSeconds = 0
        sessionStartDate = nil
        WidgetDataSync.clear()
    }

    private func startBeepSession() {
        sessionStartDate = Date.now
        sessionElapsedSeconds = 0
        isBeepSessionActive = true
        beepElapsed = 0
        beepTargetSeconds = Int.random(in: 60...300)
        widgetSyncTick = 0
        syncWidgetState()
    }

    private func stopBeepSession() {
        isBeepSessionActive = false
        beepElapsed = 0
        beepTargetSeconds = 0
        completeSession()
    }

    // MARK: - Health Module

    private var healthModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(L10n.healthTracker, icon: "heart.fill")

            VStack(spacing: 12) {
                Text(L10n.bmiCalculator).font(.headline)

                HStack(spacing: 12) {
                    HStack {
                        TextField("Weight (kg)", text: $weightText)
                            .keyboardType(.decimalPad)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        TextField("Height (cm)", text: $heightText)
                            .keyboardType(.decimalPad)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let bmi = calculatedBMI {
                    HStack {
                        Text("BMI: ")
                            .fontWeight(.semibold)
                        Text(String(format: "%.1f", bmi))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(bmiColor(bmi))
                        Text(bmiCategory(bmi))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.dietWindow).font(.headline)

                HStack {
                    DatePicker("Fast start", selection: $fastStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("→")
                    DatePicker("Fast end", selection: $fastEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }

                Text(L10n.whatDidYouEat)
                    .font(.headline)
                    .padding(.top, 4)

                TextField("e.g. Chicken and rice (40g protein / 50g carbs)", text: $foodLog)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Finance Module

    private var financeModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(L10n.portfolio, icon: "chart.pie.fill")

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.assetAllocation).font(.headline)

                Chart(MockAsset.allCases) { asset in
                    BarMark(
                        x: .value("Asset", asset.rawValue),
                        y: .value("Allocation", asset.allocation)
                    )
                    .foregroundStyle(asset.color.gradient)
                    .annotation(position: .top) {
                        Text("\(Int(asset.allocation))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.dailyDCALabel).font(.headline)

                HStack {
                    Text("$")
                    TextField("0.00", text: $dcaAmount)
                        .keyboardType(.decimalPad)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Vision / General Module

    private var visionModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.visionBoard, icon: "eye.fill")
            Text(L10n.visionBoardHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var generalModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.generalTask, icon: "square.stack.fill")
            Text(L10n.generalTaskHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(L10n.markAsDone, icon: "sparkles.rectangle.stack")

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    HStack {
                        Text(L10n.completionRateLabel)
                        Spacer()
                        Text("\(Int(completionRate))%")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Slider(value: $completionRate, in: 0...100, step: 5)
                        .tint(completionRate > 50 ? .green : .orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.thoughtsExcuses)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField(L10n.howDidItGo, text: $feedbackNote, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: submitFeedback) {
                    HStack(spacing: 8) {
                        if isSubmittingFeedback {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isSubmittingFeedback ? L10n.reflectingLabel : L10n.submitToAI)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isSubmittingFeedback)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let response = aiCoachResponse {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.indigo)
                        Text(L10n.aiCoach)
                            .font(.headline)
                            .foregroundStyle(.indigo)
                    }

                    Text(response)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .transition(.scale.combined(with: .opacity))
            }

            if let error = feedbackError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: aiCoachResponse != nil)
    }

    // MARK: - Prompt Overlay

    private func promptOverlay(_ prompt: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text(prompt)
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showPrompt = false
                }
            }
        }
    }

    // MARK: - Session Complete Overlay

    private var sessionCompleteOverlay: some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text(L10n.sessionComplete)
                    .font(.title3)
                    .fontWeight(.bold)

                Text(L10n.greatWork)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Feedback Action

    private func submitFeedback() {
        isSubmittingFeedback = true
        aiCoachResponse = nil
        feedbackError = nil

        Task {
            do {
                let response = try await AIManager().getFeedback(
                    task: task,
                    completion: completionRate,
                    note: feedbackNote
                )
                aiCoachResponse = response
                feedbackError = nil
            } catch {
                feedbackError = "Failed to get feedback: \(error.localizedDescription)"
            }
            isSubmittingFeedback = false
        }
    }

    // MARK: - Helpers

    private var taskTypeColor: Color {
        switch task.taskType {
        case .study:    return .blue
        case .health:   return .green
        case .finance:  return .orange
        case .vision:   return .purple
        case .general:  return .gray
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

    private var calculatedBMI: Double? {
        guard let weight = Double(weightText),
              let height = Double(heightText),
              weight > 0, height > 0 else { return nil }
        return weight / ((height / 100) * (height / 100))
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "(Underweight)"
        case 18.5..<25: return "(Normal)"
        case 25..<30: return "(Overweight)"
        default: return "(Obese)"
        }
    }
}

// MARK: - Mock Asset Model

private enum MockAsset: String, Identifiable, CaseIterable {
    case nasdaq = "Nasdaq-100"
    case sp500 = "S&P 500"
    case btc = "BTC"
    case cash = "Cash"

    var id: String { rawValue }

    var allocation: Double {
        switch self {
        case .nasdaq: return 30
        case .sp500:  return 40
        case .btc:    return 20
        case .cash:   return 10
        }
    }

    var color: Color {
        switch self {
        case .nasdaq: return .blue
        case .sp500:  return .green
        case .btc:    return .orange
        case .cash:   return .gray
        }
    }
}

// MARK: - Time Formatting

private func timeString(from seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
