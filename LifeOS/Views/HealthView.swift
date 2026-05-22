import SwiftUI
import SwiftData

// MARK: - HealthView

struct HealthView: View {

    @Query private var profiles: [UserProfile]
    @Query(sort: \DietEntry.date, order: .reverse) private var dietEntries: [DietEntry]
    @Query(sort: \SleepEntry.date, order: .reverse) private var sleepEntries: [SleepEntry]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moodEntries: [MoodEntry]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("language") private var language = "en"
    @AppStorage("LastHealthBriefingDate") private var lastBriefingDate: String = ""

    @State private var age: Int = 25
    @State private var weightKg: Double = 65
    @State private var targetWeightKg: Double = 65
    @State private var heightCm: Double = 170
    @State private var gender: String = "male"
    @State private var yesterdayDelta: Double = 0

    @State private var showEditSheet = false

    @State private var aiAnalysis: String?
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    @State private var debounceTask: Task<Void, Never>?

    // Diet
    @State private var mealText: String = ""
    @State private var isEstimatingCalories = false
    @State private var calorieResult: String?

    // Sleep
    @State private var sleepHours: Double = 7
    @State private var sleepComment: String = ""
    @State private var showSleepNotes: Bool = false
    @FocusState private var isSleepNotesFocused: Bool

    // Mood
    @State private var selectedMoodScore: Int = 3
    @State private var selectedMoodEmoji: String = "😐"

    // Steps
    @State private var stepCount: Int = 0
    @State private var healthKitAuthorized = false

    // History
    @State private var showHealthHistory = false

    private let healthKitManager = HealthKitManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    moodCard
                    stepsCard
                    weightProgressCard
                    sleepCard
                    dietCard
                    weeklyBriefingCard
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
            .navigationTitle(L10n.health)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHealthHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                loadData()
                Task {
                    await healthKitManager.requestAuthorization()
                    await healthKitManager.fetchTodaySteps()
                    await MainActor.run {
                        healthKitAuthorized = healthKitManager.isAuthorized
                        stepCount = healthKitManager.stepCount
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: aiAnalysis != nil)
            .sheet(isPresented: $showEditSheet) {
                editSheet
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showHealthHistory) {
                HealthHistoryView()
            }
        }
    }

    // MARK: Steps Card (HealthKit)

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.blue)
                Text(L10n.stepsToday)
                    .font(.headline)
                Spacer()
                if !healthKitAuthorized {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(L10n.healthkitDenied)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }

            if healthKitAuthorized {
                HStack(spacing: 4) {
                    Text(healthKitManager.stepCountFormatted)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                        .contentTransition(.numericText())
                    Text(L10n.stepsLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Mini progress bar toward 10,000 steps
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(CGFloat(min(stepCount, 10000)) / 10000.0 * geo.size.width, 8),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                Text("\(10000 - stepCount > 0 ? "\(10000 - stepCount) steps to goal" : "Goal reached!") ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !healthKitAuthorized {
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(L10n.enableHealthKit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task {
                            await healthKitManager.requestAuthorization()
                            await healthKitManager.fetchTodaySteps()
                            await MainActor.run {
                                healthKitAuthorized = healthKitManager.isAuthorized
                                stepCount = healthKitManager.stepCount
                            }
                        }
                    } label: {
                        Text(L10n.enableHealthKit)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Weight Progress Card

    private var weightProgressCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.green)
                Text(L10n.bodyMetrics)
                    .font(.headline)
                Spacer()
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }

            VStack(spacing: 12) {
                HStack {
                    Text(L10n.weightLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f kg", weightKg))
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }

                let progress = weightProgressFraction
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.12))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: weightGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geo.size.width * CGFloat(progress), 12), height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(width: 3, height: 20)
                            .offset(x: geo.size.width * targetProgressPosition - 1.5)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text(String(format: "%.1f kg", 0.0))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("Target: \(String(format: "%.1f kg", targetWeightKg))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }

                targetGapLabel

                HStack(spacing: 0) {
                    Text(L10n.yesterdayDelta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        let raw = yesterdayDelta - 0.1
                        yesterdayDelta = (raw * 10).rounded() / 10
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    Text(String(format: "%+.1f", yesterdayDelta))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(yesterdayDelta > 0 ? Color.red : (yesterdayDelta < 0 ? Color.green : Color.primary))
                        .frame(minWidth: 56)
                        .multilineTextAlignment(.center)
                    Button {
                        let raw = yesterdayDelta + 0.1
                        yesterdayDelta = (raw * 10).rounded() / 10
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 2)
                }
                .onChange(of: yesterdayDelta) { oldDelta, newDelta in
                    if abs(newDelta - oldDelta) > 0.001 {
                        let rawWeight = weightKg - oldDelta + newDelta
                        weightKg = (rawWeight * 10).rounded() / 10
                    }
                    debouncedSave()
                }
            }

            Divider()

            let bmi = calculatedBMI
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.bmiLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", bmi))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(bmiColor(bmi))
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(bmiCategory(bmi))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(bmiColor(bmi))
                    bmiScale(bmi)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Target Gap Label

    private var targetGapLabel: some View {
        let delta = targetWeightKg - weightKg
        if abs(delta) > 0.05 {
            return AnyView(
                Text(delta > 0 ? L10n.targetGap(delta) : L10n.targetGapOver(delta))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(delta > 0 ? Color.blue : Color.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background((delta > 0 ? Color.blue : Color.orange).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
        } else {
            return AnyView(
                Text("At target weight!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
        }
    }

    // MARK: BMI Scale

    private func bmiScale(_ bmi: Double) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(.blue).frame(width: 14, height: 4)
            Rectangle().fill(.green).frame(width: 14, height: 4)
            Rectangle().fill(.orange).frame(width: 14, height: 4)
            Rectangle().fill(.red).frame(width: 14, height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.primary)
                .frame(width: 2.5, height: 10)
                .offset(x: bmiScaleOffset(bmi)),
            alignment: .center
        )
    }

    private func bmiScaleOffset(_ bmi: Double) -> CGFloat {
        let totalWidth: CGFloat = 56
        let clamped = min(max(bmi, 10), 45)
        return (clamped - 10) / 35 * totalWidth - totalWidth / 2
    }

    // MARK: Diet Card

    private var dietCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(.orange)
                Text(L10n.diet)
                    .font(.headline)
                Spacer()
                Text(L10n.thisWeek)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            // Meal input
            HStack(spacing: 8) {
                TextField(L10n.mealPlaceholder, text: $mealText, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...2)
                Button {
                    logMeal()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(mealText.isEmpty ? Color.secondary : Color.orange)
                }
                .disabled(mealText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Calorie estimation result
            if let calorieResult = calorieResult {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(calorieResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation { self.calorieResult = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .background(.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // This week's diet entries
            let weekEntries = thisWeekEntries(dietEntries)
            if weekEntries.isEmpty {
                Text(L10n.noDataThisWeek)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ForEach(weekEntries.prefix(7)) { entry in
                    dietRow(entry)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dietRow(_ entry: DietEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.mealText)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if entry.estimatedCalories == nil {
                Button {
                    estimateCaloriesForEntry(entry)
                } label: {
                    if isEstimatingCalories {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.orange)
                    } else {
                        Text(L10n.estimateCalories)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("~\(entry.estimatedCalories!)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text(L10n.kcal)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Sleep Card

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.indigo)
                Text(L10n.sleep)
                    .font(.headline)
                Spacer()
                let avg = weeklySleepAverage
                if avg > 0 {
                    Text("\(L10n.weeklyAverage): \(String(format: "%.1f", avg))h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        TextField("7", value: $sleepHours, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                            .fontWeight(.bold)
                            .frame(width: 44)
                            .multilineTextAlignment(.center)
                        Text(L10n.hours)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField(L10n.sleepQualityPlaceholder, text: $sleepComment)
                        .font(.subheadline)
                    Button {
                        logSleep()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSleepNotes = false
                            sleepComment = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                    }
                    .disabled(sleepHours <= 0)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: sleepHours) { _, newValue in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showSleepNotes = newValue > 0 && newValue < 6
                    }
                }

                // Sleep notes accordion (expands when sleep < 6 hours)
                if showSleepNotes {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(L10n.sleepNotesHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        TextField(L10n.sleepQualityPlaceholder, text: $sleepComment, axis: .vertical)
                            .font(.subheadline)
                            .focused($isSleepNotesFocused)
                            .lineLimit(1...3)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Weekly sleep chart
            let weekSleep = thisWeekSleepEntries
            if weekSleep.isEmpty {
                Text(L10n.noDataThisWeek)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                sleepWeeklyChart(weekSleep)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sleepWeeklyChart(_ entries: [SleepEntry]) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(weekdayLabels(), id: \.0) { day, label in
                        let entry = entries.first(where: { weekdayOf($0.date) == day })
                        let hours = entry?.hoursSlept ?? 0
                        let maxH: Double = 12
                        let barHeight = max(geo.size.height * CGFloat(hours / maxH), hours > 0 ? 4 : 0)
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(hours > 0 ? Color.indigo.opacity(0.6) : Color.gray.opacity(0.15))
                                .frame(height: barHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            Text(label)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 60)
        }
    }

    // MARK: Mood Card

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "face.smiling")
                    .foregroundStyle(.pink)
                Text(L10n.mood)
                    .font(.headline)
                Spacer()
            }

            // Emoji selector
            HStack(spacing: 12) {
                ForEach(MoodEntry.emojiScale, id: \.score) { item in
                    Button {
                        selectedMoodEmoji = item.emoji
                        selectedMoodScore = item.score
                    } label: {
                        VStack(spacing: 2) {
                            Text(item.emoji)
                                .font(.system(size: 28))
                            Circle()
                                .fill(selectedMoodScore == item.score ? Color.pink : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(selectedMoodScore == item.score ? Color.pink.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    logMood()
                } label: {
                    Text(L10n.logMood)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.pink)
                }
                .buttonStyle(.bordered)
                .tint(.pink)
                .controlSize(.small)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Weekly mood chart
            let weekMoods = thisWeekMoodEntries
            if weekMoods.isEmpty {
                Text(L10n.noDataThisWeek)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                moodWeeklyChart(weekMoods)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func moodWeeklyChart(_ entries: [MoodEntry]) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let maxScore: Double = 5
                let minScore: Double = 1
                let points = weekdayLabels().compactMap { day, _ -> CGPoint? in
                    let entry = entries.first(where: { weekdayOf($0.date) == day })
                    guard let score = entry?.score else { return nil }
                    let x = geo.size.width * CGFloat(day - 1) / 6
                    let y = geo.size.height * CGFloat(1 - (Double(score) - minScore) / (maxScore - minScore))
                    return CGPoint(x: x, y: y)
                }
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(Color.pink.opacity(0.5), lineWidth: 2)

                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 6, height: 6)
                            .position(pt)
                    }
                }
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(weekdayLabels(), id: \.0) { day, label in
                        let entry = entries.first(where: { weekdayOf($0.date) == day })
                        VStack(spacing: 2) {
                            Spacer()
                            if let emoji = entry?.emoji {
                                Text(emoji)
                                    .font(.system(size: 14))
                            }
                            Text(label)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 70)
        }
    }

    // MARK: Weekly AI Briefing Card

    private var weeklyBriefingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.green)
                Text(L10n.aiHealthAnalyst)
                    .font(.headline)
                Spacer()
                if isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.green)
                }
            }

            if let analysis = aiAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    let sections = parseAnalysisSections(analysis)
                    ForEach(sections.prefix(3), id: \.title) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                            Text(section.content)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else if analysisError != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("Briefing unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)

                    if canGenerateBriefing {
                        Text(L10n.briefingReady)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text(L10n.nextBriefingIn)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        runHealthAnalysis()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text(L10n.generateBriefing)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .disabled(!canGenerateBriefing)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var canGenerateBriefing: Bool {
        guard !lastBriefingDate.isEmpty else { return true }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let lastDate = formatter.date(from: lastBriefingDate) else { return true }
        return !Calendar.current.isDate(lastDate, inSameDayAs: Date.now)
    }

    // MARK: Edit Sheet

    private var editSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.genderLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker(L10n.genderLabel, selection: $gender) {
                            Text(L10n.male).tag("male")
                            Text(L10n.female).tag("female")
                        }
                        .pickerStyle(.segmented)
                        .id(language)
                        .onChange(of: gender) { _, _ in debouncedSave() }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.ageLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField(L10n.ageLabel, value: $age, format: .number)
                                .keyboardType(.numberPad)
                                .font(.body)
                            Text("years")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: age) { _, _ in debouncedSave() }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.heightLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("cm", value: $heightCm, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.body)
                            Text("cm")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: heightCm) { _, _ in debouncedSave() }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.weightLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("kg", value: $weightKg, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.body)
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: weightKg) { _, _ in debouncedSave() }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.targetWeightLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("kg", value: $targetWeightKg, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.body)
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: targetWeightKg) { _, _ in debouncedSave() }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.bodyMetrics)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        showEditSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Computed

    private var calculatedBMI: Double {
        guard heightCm > 0, weightKg > 0 else { return 0 }
        return weightKg / ((heightCm / 100) * (heightCm / 100))
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

    // MARK: Weight Progress Helpers

    private var weightProgressFraction: Double {
        guard targetWeightKg > 0 else { return 0 }
        let maxWeight = max(weightKg, targetWeightKg) * 1.15
        guard maxWeight > 0 else { return 0 }
        let fraction = weightKg / maxWeight
        return min(max(fraction, 0.01), 1.0)
    }

    private var targetProgressPosition: CGFloat {
        guard targetWeightKg > 0 else { return 0 }
        let maxWeight = max(weightKg, targetWeightKg) * 1.15
        guard maxWeight > 0 else { return 0 }
        return CGFloat(min(max(targetWeightKg / maxWeight, 0.01), 1.0))
    }

    private var weightGradientColors: [Color] {
        let delta = abs(weightKg - targetWeightKg)
        if delta < 1 { return [.green, .green.opacity(0.7)] }
        if delta < 5 { return [.green, .orange] }
        return [.orange, .red.opacity(0.7)]
    }

    // MARK: Weekly Helpers

    private var weeklySleepAverage: Double {
        let weekEntries = thisWeekSleepEntries
        guard !weekEntries.isEmpty else { return 0 }
        let total = weekEntries.reduce(0) { $0 + $1.hoursSlept }
        return total / Double(weekEntries.count)
    }

    private var thisWeekSleepEntries: [SleepEntry] {
        sleepEntries.filter { Calendar.current.isDate($0.date, equalTo: Date.now, toGranularity: .weekOfYear) }
    }

    private func thisWeekEntries<T>(_ entries: [T]) -> [T] where T: AnyObject {
        // Filter entries from this week
        // Since we can't guarantee protocol conformance, use a basic filter
        return entries.compactMap { entry in
            if let dietEntry = entry as? DietEntry {
                return Calendar.current.isDate(dietEntry.date, equalTo: Date.now, toGranularity: .weekOfYear) ? entry : nil
            }
            return nil
        }
    }

    private var thisWeekDietEntries: [DietEntry] {
        dietEntries.filter { Calendar.current.isDate($0.date, equalTo: Date.now, toGranularity: .weekOfYear) }
    }

    private var thisWeekMoodEntries: [MoodEntry] {
        moodEntries.filter { Calendar.current.isDate($0.date, equalTo: Date.now, toGranularity: .weekOfYear) }
    }

    private func weekdayLabels() -> [(Int, String)] {
        let isZh = language == "zh-Hans"
        return [
            (1, isZh ? "日" : "Sun"),
            (2, isZh ? "一" : "Mon"),
            (3, isZh ? "二" : "Tue"),
            (4, isZh ? "三" : "Wed"),
            (5, isZh ? "四" : "Thu"),
            (6, isZh ? "五" : "Fri"),
            (7, isZh ? "六" : "Sat")
        ]
    }

    private func weekdayOf(_ date: Date) -> Int {
        Calendar.current.component(.weekday, from: date)
    }

    // MARK: Persistence

    private func loadData() {
        if let profile = profiles.first {
            age = profile.age
            weightKg = profile.weightKg
            targetWeightKg = profile.targetWeightKg
            heightCm = profile.heightCm
            gender = profile.gender
            yesterdayDelta = profile.yesterdayWeightDelta
        }
    }

    private func debouncedSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                saveProfile()
            }
        }
    }

    private func saveProfile() {
        if let profile = profiles.first {
            profile.age = age
            profile.weightKg = weightKg
            profile.targetWeightKg = targetWeightKg
            profile.heightCm = heightCm
            profile.gender = gender
            profile.yesterdayWeightDelta = yesterdayDelta
        } else {
            let new = UserProfile(
                heightCm: heightCm,
                weightKg: weightKg,
                targetWeightKg: targetWeightKg,
                age: age,
                gender: gender,
                yesterdayWeightDelta: yesterdayDelta
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
    }

    // MARK: Diet Logging

    private func logMeal() {
        let text = mealText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let entry = DietEntry(date: Date.now, mealText: text)
        modelContext.insert(entry)
        try? modelContext.save()
        mealText = ""
    }

    private func estimateCaloriesForEntry(_ entry: DietEntry) {
        isEstimatingCalories = true
        Task {
            do {
                let result = try await AIManager().estimateCalories(
                    mealText: entry.mealText,
                    language: language
                )
                await MainActor.run {
                    entry.estimatedCalories = extractCalorieNumber(result)
                    try? modelContext.save()
                    isEstimatingCalories = false
                }
            } catch {
                await MainActor.run {
                    isEstimatingCalories = false
                }
            }
        }
    }

    private func extractCalorieNumber(_ text: String) -> Int? {
        let regex = /(\d+)\s*kcal/
        if let match = text.firstMatch(of: regex) {
            return Int(match.1)
        }
        // Fallback: try to find any number before "kcal"
        let parts = text.components(separatedBy: "kcal")
        if let first = parts.first {
            let numbers = first.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            return numbers.last
        }
        return nil
    }

    // MARK: Sleep Logging

    private func logSleep() {
        guard sleepHours > 0, sleepHours <= 24 else { return }
        let comment = sleepComment.trimmingCharacters(in: .whitespaces)
        let entry = SleepEntry(
            date: Date.now,
            hoursSlept: (sleepHours * 10).rounded() / 10,
            qualityComment: comment.isEmpty ? nil : comment
        )
        modelContext.insert(entry)
        try? modelContext.save()
        sleepHours = 7
        sleepComment = ""
    }

    // MARK: Mood Logging

    private func logMood() {
        let entry = MoodEntry(
            date: Date.now,
            emoji: selectedMoodEmoji,
            score: selectedMoodScore
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    // MARK: AI Analysis

    private func runHealthAnalysis() {
        isAnalyzing = true
        analysisError = nil

        Task {
            do {
                let targetGap = targetWeightKg - weightKg
                let result = try await AIManager().analyzeHealth(
                    gender: gender,
                    age: age,
                    heightCm: heightCm,
                    weightKg: weightKg,
                    targetWeightKg: targetWeightKg,
                    yesterdayDelta: yesterdayDelta,
                    targetGap: targetGap,
                    language: language
                )
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        aiAnalysis = result
                        analysisError = nil
                    }
                    // Record briefing date
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    lastBriefingDate = formatter.string(from: Date.now)
                }
            } catch {
                await MainActor.run {
                    analysisError = error.localizedDescription
                }
            }
            await MainActor.run {
                isAnalyzing = false
            }
        }
    }

    private func parseAnalysisSections(_ text: String) -> [(title: String, content: String)] {
        let lines = text.components(separatedBy: "\n")
        var sections: [(title: String, content: String)] = []
        var currentTitle = ""
        var currentContent: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                if !currentContent.isEmpty { currentContent.append("") }
                continue
            }
            let uppercased = trimmed.uppercased()
            if uppercased == trimmed && trimmed.allSatisfy({ $0.isUppercase || $0 == " " || $0 == "&" }) && trimmed.count > 3 {
                if !currentTitle.isEmpty {
                    sections.append((title: currentTitle, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = trimmed.capitalized
                currentContent = []
            } else {
                currentContent.append(trimmed)
            }
        }
        if !currentTitle.isEmpty {
            sections.append((title: currentTitle, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if sections.isEmpty {
            sections.append((title: "Analysis", content: text))
        }
        return sections
    }
}
