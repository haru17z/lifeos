import SwiftUI
import Charts
import AVFoundation

// MARK: - TaskDetailView

struct TaskDetailView: View {
    let task: LifeTask

    // MARK: Feedback State
    @State private var completionRate: Double = 50
    @State private var feedbackNote: String = ""
    @State private var isSubmittingFeedback = false
    @State private var aiCoachResponse: String?
    @State private var feedbackError: String?

    // MARK: Study State
    @State private var studyMethod: StudyMethod = .pomodoro
    @State private var pomodoroRemaining: Int = 1500
    @State private var isPomodoroRunning = false
    @State private var beepTargetSeconds: Int = 0
    @State private var beepElapsed: Int = 0
    @State private var isBeepSessionActive = false

    // MARK: Health State
    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var fastStart = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var fastEnd = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var foodLog: String = ""

    // MARK: Finance State
    @State private var dcaAmount: String = ""

    private let pomodoroTotal: Int = 1500

    enum StudyMethod: String, CaseIterable {
        case pomodoro = "Pomodoro"
        case randomBeep = "Random Beep"
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Header Card ──
                headerCard

                // ── Module Section ──
                switch task.taskType {
                case .study:    studyModule
                case .health:   healthModule
                case .finance:  financeModule
                case .vision:   visionModule
                case .general:  generalModule
                }

                Divider()

                // ── Feedback Section ──
                feedbackSection
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .dismissKeyboardOnTap()
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Pomodoro tick
            if isPomodoroRunning && pomodoroRemaining > 0 {
                pomodoroRemaining -= 1
            }

            // Random Beep tick
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Study Module

    private var studyModule: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    .contentTransition(.numericText())
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

    // MARK: - Health Module

    private var healthModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Health Tracker", icon: "heart.fill")

            // BMI
            VStack(spacing: 12) {
                Text("BMI Calculator").font(.headline)

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
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Diet Window
            VStack(alignment: .leading, spacing: 12) {
                Text("Diet Window (16:8 Fasting)").font(.headline)

                HStack {
                    DatePicker("Fast start", selection: $fastStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("→")
                    DatePicker("Fast end", selection: $fastEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }

                Text("What did you eat? (Protein/Carb ratio)")
                    .font(.headline)
                    .padding(.top, 4)

                TextField("e.g. Chicken and rice (40g protein / 50g carbs)", text: $foodLog)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Finance Module

    private var financeModule: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Portfolio Overview", icon: "chart.pie.fill")

            // Mock Allocation Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Asset Allocation").font(.headline)

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
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // DCA
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily DCA").font(.headline)

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
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Vision / General Module

    private var visionModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Vision Board", icon: "eye.fill")
            Text("Visualize your long-term goals. Use this space to reflect on your bigger picture.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var generalModule: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("General Task", icon: "square.stack.fill")
            Text("No special module for this task type. Mark your progress below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Mark as Done / Review", icon: "sparkles.rectangle.stack")

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
                        Text(isSubmittingFeedback ? "Reflecting..." : "Submit to AI Coach")
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
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // AI Coach Response
            if let response = aiCoachResponse {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.indigo)
                        Text("AI Coach")
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

    // MARK: - Actions

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

    // MARK: - Pomodoro Logic

    private func startPomodoro() {
        isPomodoroRunning = true
    }

    private func pausePomodoro() {
        isPomodoroRunning = false
    }

    private func resetPomodoro() {
        isPomodoroRunning = false
        pomodoroRemaining = pomodoroTotal
    }

    private func stopPomodoroTimer() {
        isPomodoroRunning = false
    }

    // MARK: - Random Beep Logic

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
