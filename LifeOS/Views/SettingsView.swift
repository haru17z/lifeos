import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SettingsView

struct SettingsView: View {

    @AppStorage("theme") private var theme = "system"
    @AppStorage("language") private var language = "en"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    // JSON Import
    @State private var showFileImporter = false
    @State private var showImportStrategy = false
    @State private var pendingImportURL: URL?
    @State private var isImporting = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                languageSection
                dataSection
            }
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        pendingImportURL = url
                        showImportStrategy = true
                    }
                case .failure(let error):
                    importMessage = error.localizedDescription
                }
            }
            .confirmationDialog(
                L10n.importTitle,
                isPresented: $showImportStrategy,
                titleVisibility: .visible
            ) {
                Button(L10n.overwriteOption) {
                    if let url = pendingImportURL {
                        performImport(url: url, strategy: .overwrite)
                    }
                }
                Button(L10n.mergeOption) {
                    if let url = pendingImportURL {
                        performImport(url: url, strategy: .merge)
                    }
                }
                Button(L10n.cancel, role: .cancel) {
                    pendingImportURL = nil
                }
            } message: {
                Text(L10n.importMessage)
            }
            .alert(L10n.importSuccess, isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button(L10n.ok) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section(L10n.appearance) {
            Picker(L10n.appearance, selection: $theme) {
                Text(L10n.light).tag("light")
                Text(L10n.dark).tag("dark")
                Text(L10n.system).tag("system")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Language

    private var languageSection: some View {
        Section(L10n.language) {
            Picker(L10n.language, selection: $language) {
                Text(L10n.englishLabel).tag("en")
                Text(L10n.chineseLabel).tag("zh-Hans")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            Button {
                performExport()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.indigo)
                    Text(isExporting
                         ? (language == "zh-Hans" ? "导出中…" : "Exporting...")
                         : (language == "zh-Hans" ? "导出数据 (JSON)" : "Export Data (JSON)"))
                    Spacer()
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isExporting)

            Button {
                showFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.orange)
                    Text(isImporting
                         ? (language == "zh-Hans" ? "导入中…" : "Importing...")
                         : L10n.importData)
                    Spacer()
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isImporting)
        } footer: {
            Text(language == "zh-Hans"
                 ? "将所有任务、健康档案、持仓及专注记录导出至本地 JSON 文件。也可从 JSON 文件导入数据。"
                 : "Export all tasks, health profiles, holdings, and focus sessions to a local JSON file. You can also import data from a JSON file.")
        }
    }

    // MARK: Export Action

    private func performExport() {
        isExporting = true
        exportError = nil

        do {
            let url = try LifeOSExporter.exportAllData(context: modelContext)
            exportURL = url
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    // MARK: Import

    private enum ImportStrategy {
        case overwrite
        case merge
    }

    private func performImport(url: URL, strategy: ImportStrategy) {
        isImporting = true
        importMessage = nil

        guard url.startAccessingSecurityScopedResource() else {
            importMessage = language == "zh-Hans" ? "无法访问文件" : "Cannot access file"
            isImporting = false
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let export = try decoder.decode(LifeOSExport.self, from: data)

            if strategy == .overwrite {
                // Delete all existing data
                let allTasks = try modelContext.fetch(FetchDescriptor<LifeTask>())
                let allGoals = try modelContext.fetch(FetchDescriptor<PeriodGoal>())
                let allProfiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
                let allFinance = try modelContext.fetch(FetchDescriptor<FinanceData>())
                let allSessions = try modelContext.fetch(FetchDescriptor<FocusSession>())
                let allHoldings = try modelContext.fetch(FetchDescriptor<Holding>())
                let allDiet = try modelContext.fetch(FetchDescriptor<DietEntry>())
                let allSleep = try modelContext.fetch(FetchDescriptor<SleepEntry>())
                let allMood = try modelContext.fetch(FetchDescriptor<MoodEntry>())
                let allTransactions = try modelContext.fetch(FetchDescriptor<TransactionRecord>())

                for item in allTasks { modelContext.delete(item) }
                for item in allGoals { modelContext.delete(item) }
                for item in allProfiles { modelContext.delete(item) }
                for item in allFinance { modelContext.delete(item) }
                for item in allSessions { modelContext.delete(item) }
                for item in allHoldings { modelContext.delete(item) }
                for item in allDiet { modelContext.delete(item) }
                for item in allSleep { modelContext.delete(item) }
                for item in allMood { modelContext.delete(item) }
                for item in allTransactions { modelContext.delete(item) }
            }

            // Insert imported data
            LifeOSExporter.importFromExport(export, context: modelContext)
            try modelContext.save()

            let count = export.tasks.count + export.holdings.count + export.focusSessions.count
            importMessage = language == "zh-Hans"
                ? "已导入 \(count) 条记录"
                : "Imported \(count) records"
        } catch {
            importMessage = (language == "zh-Hans" ? "导入失败: " : "Import failed: ") + error.localizedDescription
        }

        isImporting = false
        pendingImportURL = nil
    }
}

// MARK: - LifeOSExporter

private enum LifeOSExporter {

    static func exportAllData(context: ModelContext) throws -> URL {
        let allTasks = try context.fetch(FetchDescriptor<LifeTask>())
        let allGoals = try context.fetch(FetchDescriptor<PeriodGoal>())
        let allProfiles = try context.fetch(FetchDescriptor<UserProfile>())
        let allFinance = try context.fetch(FetchDescriptor<FinanceData>())
        let allSessions = try context.fetch(FetchDescriptor<FocusSession>())
        let allHoldings = try context.fetch(FetchDescriptor<Holding>())
        let allDiet = try context.fetch(FetchDescriptor<DietEntry>())
        let allSleep = try context.fetch(FetchDescriptor<SleepEntry>())
        let allMood = try context.fetch(FetchDescriptor<MoodEntry>())
        let allTransactions = try context.fetch(FetchDescriptor<TransactionRecord>())

        let export = LifeOSExport(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            tasks: allTasks.map(ExportedTask.init),
            goals: allGoals.map(ExportedGoal.init),
            profiles: allProfiles.map(ExportedProfile.init),
            financeData: allFinance.map(ExportedFinance.init),
            focusSessions: allSessions.map(ExportedSession.init),
            holdings: allHoldings.map(ExportedHolding.init),
            dietEntries: allDiet.map(ExportedDietEntry.init),
            sleepEntries: allSleep.map(ExportedSleepEntry.init),
            moodEntries: allMood.map(ExportedMoodEntry.init),
            transactions: allTransactions.map(ExportedTransaction.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let fileName = "LifeOS_Export_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }

    static func importFromExport(_ export: LifeOSExport, context: ModelContext) {
        for t in export.tasks {
            let task = LifeTask(
                title: t.title,
                targetDate: ISO8601DateFormatter().date(from: t.targetDate) ?? Date(),
                timeDisplay: t.timeDisplay,
                location: t.location,
                notes: t.notes,
                taskType: TaskType(rawValue: t.taskType) ?? .general,
                isCompleted: t.isCompleted,
                isExactTime: t.isExactTime,
                pomodoroSets: t.pomodoroSets
            )
            context.insert(task)
        }
        for g in export.goals {
            let goal = PeriodGoal(type: g.type, content: g.content)
            context.insert(goal)
        }
        for p in export.profiles {
            let profile = UserProfile(
                heightCm: p.heightCm,
                weightKg: p.weightKg,
                targetWeightKg: p.targetWeightKg,
                age: p.age,
                gender: p.gender
            )
            profile.yesterdayWeightDelta = p.yesterdayWeightDelta
            context.insert(profile)
        }
        for f in export.financeData {
            let fd = FinanceData(dailyDCAAmount: f.dailyDCAAmount)
            context.insert(fd)
        }
        for s in export.focusSessions {
            let session = FocusSession(
                date: ISO8601DateFormatter().date(from: s.date) ?? Date(),
                durationSeconds: s.durationSeconds,
                method: s.method,
                setsCompleted: s.setsCompleted,
                totalSets: s.totalSets,
                studyContent: s.studyContent
            )
            context.insert(session)
        }
        for h in export.holdings {
            let holding = Holding(
                ticker: h.ticker,
                name: h.name,
                amountInvested: h.amountInvested,
                currentValue: h.currentValue,
                currentDailyPrice: h.currentDailyPrice,
                previousClose: h.previousClose,
                sharesOwned: h.sharesOwned
            )
            context.insert(holding)
        }
        for d in export.dietEntries {
            let entry = DietEntry(
                date: ISO8601DateFormatter().date(from: d.date) ?? Date(),
                mealText: d.mealText,
                estimatedCalories: d.estimatedCalories
            )
            context.insert(entry)
        }
        for s in export.sleepEntries {
            let entry = SleepEntry(
                date: ISO8601DateFormatter().date(from: s.date) ?? Date(),
                hoursSlept: s.hoursSlept,
                qualityComment: s.qualityComment
            )
            context.insert(entry)
        }
        for m in export.moodEntries {
            let entry = MoodEntry(
                date: ISO8601DateFormatter().date(from: m.date) ?? Date(),
                emoji: m.emoji,
                score: m.score
            )
            context.insert(entry)
        }
        for t in export.transactions {
            let record = TransactionRecord(
                date: ISO8601DateFormatter().date(from: t.date) ?? Date(),
                ticker: t.ticker,
                action: t.action,
                detail: t.detail
            )
            context.insert(record)
        }
    }
}

// MARK: - Export Structs

private struct LifeOSExport: Codable {
    let exportedAt: String
    let tasks: [ExportedTask]
    let goals: [ExportedGoal]
    let profiles: [ExportedProfile]
    let financeData: [ExportedFinance]
    let focusSessions: [ExportedSession]
    let holdings: [ExportedHolding]
    var dietEntries: [ExportedDietEntry] = []
    var sleepEntries: [ExportedSleepEntry] = []
    var moodEntries: [ExportedMoodEntry] = []
    var transactions: [ExportedTransaction] = []
}

private struct ExportedTask: Codable {
    let id: String
    let title: String
    let timeDisplay: String
    let targetDate: String
    let taskType: String
    let isCompleted: Bool
    let location: String?
    let notes: String?
    let isExactTime: Bool
    let pomodoroSets: Int

    init(_ task: LifeTask) {
        self.id = task.id.uuidString
        self.title = task.title
        self.timeDisplay = task.timeDisplay
        self.targetDate = ISO8601DateFormatter().string(from: task.targetDate)
        self.taskType = task.taskType.rawValue
        self.isCompleted = task.isCompleted
        self.location = task.location
        self.notes = task.notes
        self.isExactTime = task.isExactTime
        self.pomodoroSets = task.pomodoroSets
    }
}

private struct ExportedGoal: Codable {
    let id: String
    let type: String
    let content: String

    init(_ goal: PeriodGoal) {
        self.id = goal.id.uuidString
        self.type = goal.type
        self.content = goal.content
    }
}

private struct ExportedProfile: Codable {
    let id: String
    let gender: String
    let age: Int
    let heightCm: Double
    let weightKg: Double
    let targetWeightKg: Double
    let yesterdayWeightDelta: Double
    let bmi: Double

    init(_ profile: UserProfile) {
        self.id = profile.id.uuidString
        self.gender = profile.gender
        self.age = profile.age
        self.heightCm = profile.heightCm
        self.weightKg = profile.weightKg
        self.targetWeightKg = profile.targetWeightKg
        self.yesterdayWeightDelta = profile.yesterdayWeightDelta
        self.bmi = profile.bmi
    }
}

private struct ExportedFinance: Codable {
    let id: String
    let dailyDCAAmount: Double

    init(_ data: FinanceData) {
        self.id = data.id.uuidString
        self.dailyDCAAmount = data.dailyDCAAmount
    }
}

private struct ExportedSession: Codable {
    let id: String
    let date: String
    let durationSeconds: Int
    let method: String
    let setsCompleted: Int
    let totalSets: Int
    let studyContent: String?

    init(_ session: FocusSession) {
        self.id = session.id.uuidString
        self.date = ISO8601DateFormatter().string(from: session.date)
        self.durationSeconds = session.durationSeconds
        self.method = session.method
        self.setsCompleted = session.setsCompleted
        self.totalSets = session.totalSets
        self.studyContent = session.studyContent
    }
}

private struct ExportedHolding: Codable {
    let id: String
    let ticker: String
    let name: String
    let amountInvested: Double
    let currentValue: Double
    let dailyChange: Double
    let dailyChangePercent: Double
    let currentDailyPrice: Double
    var previousClose: Double = 0
    let sharesOwned: Double
    let pnl: Double
    let pnlPercent: Double

    init(_ holding: Holding) {
        self.id = holding.id.uuidString
        self.ticker = holding.ticker
        self.name = holding.name
        self.amountInvested = holding.safeAmountInvested
        self.currentValue = holding.safeCurrentValue
        self.dailyChange = holding.safeDailyChange
        self.dailyChangePercent = holding.safeDailyChangePercent
        self.currentDailyPrice = holding.currentDailyPrice
        self.previousClose = holding.previousClose
        self.sharesOwned = holding.sharesOwned
        self.pnl = holding.absolutePnL
        self.pnlPercent = holding.pnlPercent
    }
}

private struct ExportedDietEntry: Codable {
    let id: String
    let date: String
    let mealText: String
    let estimatedCalories: Int?

    init(_ entry: DietEntry) {
        self.id = entry.id.uuidString
        self.date = ISO8601DateFormatter().string(from: entry.date)
        self.mealText = entry.mealText
        self.estimatedCalories = entry.estimatedCalories
    }
}

private struct ExportedSleepEntry: Codable {
    let id: String
    let date: String
    let hoursSlept: Double
    let qualityComment: String?

    init(_ entry: SleepEntry) {
        self.id = entry.id.uuidString
        self.date = ISO8601DateFormatter().string(from: entry.date)
        self.hoursSlept = entry.hoursSlept
        self.qualityComment = entry.qualityComment
    }
}

private struct ExportedMoodEntry: Codable {
    let id: String
    let date: String
    let emoji: String
    let score: Int

    init(_ entry: MoodEntry) {
        self.id = entry.id.uuidString
        self.date = ISO8601DateFormatter().string(from: entry.date)
        self.emoji = entry.emoji
        self.score = entry.score
    }
}

private struct ExportedTransaction: Codable {
    let id: String
    let date: String
    let ticker: String
    let action: String
    let detail: String

    init(_ record: TransactionRecord) {
        self.id = record.id.uuidString
        self.date = ISO8601DateFormatter().string(from: record.date)
        self.ticker = record.ticker
        self.action = record.action
        self.detail = record.detail
    }
}

// MARK: - ShareSheet (UIKit Bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - URL Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    SettingsView()
}
