import SwiftUI
import SwiftData
import PhotosUI

// MARK: - VisionView

struct VisionView: View {

    @Query(sort: \LifeTask.targetDate) private var tasks: [LifeTask]
    @Query private var goals: [PeriodGoal]
    @Query private var focusSessions: [FocusSession]
    @Query private var profiles: [UserProfile]
    @Query private var holdings: [Holding]
    @Environment(\.modelContext) private var modelContext

    @State private var editingGoal: PeriodGoal?
    @State private var editingContent: String = ""

    // AI Summary
    @State private var isSummarizing = false
    @State private var aiSummary: String?
    @State private var summaryError: String?
    @State private var translatedSummary: String?
    @State private var isTranslatingSummary = false
    @State private var isSummaryTranslated = false

    // Per-card AI summarize
    @State private var isSummarizingWeek = false
    @State private var isSummarizingMonth = false

    // Translation state per card
    @State private var isWeekTranslated = false
    @State private var isMonthTranslated = false
    @State private var translatedWeekContent: String?
    @State private var translatedMonthContent: String?
    @State private var isTranslatingWeek = false
    @State private var isTranslatingMonth = false

    // Dream Board
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var dreamImages: [DreamImageData] = []
    @State private var dreamText: String = ""
    @State private var showDreamEditor = false

    @AppStorage("language") private var language = "en"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // AI Summarize button
                    aiSummarizeBar

                    // Summary result
                    if let summary = aiSummary {
                        aiSummaryCard(summary)
                    }

                    weekFocusCard
                    monthFocusCard
                    dreamBoardSection
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.visionOverview)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingGoal) { goal in
                goalEditSheet(goal: goal)
            }
            .sheet(isPresented: $showDreamEditor) {
                dreamEditorSheet
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: aiSummary != nil)
        }
    }

    // MARK: Period Goal Accessors

    private var weeklyGoal: PeriodGoal {
        if let existing = goals.first(where: { $0.type == "Weekly" }) {
            return existing
        }
        let new = PeriodGoal(type: "Weekly")
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    private var monthlyGoal: PeriodGoal {
        if let existing = goals.first(where: { $0.type == "Monthly" }) {
            return existing
        }
        let new = PeriodGoal(type: "Monthly")
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    // MARK: AI Summarize Bar

    private var aiSummarizeBar: some View {
        Button {
            runAISummary()
        } label: {
            HStack(spacing: 10) {
                if isSummarizing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.indigo)
                }
                Image(systemName: "sparkles")
                    .font(.title3)
                    .symbolEffect(.bounce, options: .repeating, value: isSummarizing)
                Text(isSummarizing ? L10n.thinking : L10n.aiSummarize)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.indigo)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSummarizing)
    }

    // MARK: AI Summary Card

    private func aiSummaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkle")
                    .foregroundStyle(.indigo)
                Text("AI Cross-Domain Summary")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        aiSummary = nil
                        translatedSummary = nil
                        isSummaryTranslated = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }

            let displayText = isSummaryTranslated ? (translatedSummary ?? text) : text
            let domains = parseSummaryDomains(displayText)
            ForEach(domains, id: \.title) { domain in
                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(domainColor(domain.title))
                    Text(domain.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func domainColor(_ title: String) -> Color {
        if title.contains("STUDY") || title.contains("FOCUS") { return .blue }
        if title.contains("HEALTH") { return .green }
        if title.contains("FINANCE") { return .orange }
        if title.contains("OVERALL") { return .purple }
        return .secondary
    }

    // MARK: Week Focus Card

    private var weekFocusCard: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                editingGoal = weeklyGoal
                editingContent = weeklyGoal.content
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.indigo)
                        Text(L10n.thisWeekFocus)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()

                        // AI Summarize button
                        Button {
                            isSummarizingWeek = true
                            let relevantTasks = tasksForPeriod("Weekly")
                            Task {
                                if let summary = try? await AIManager().summarizeFocus(
                                    periodLabel: "week",
                                    tasks: relevantTasks,
                                    language: language
                                ) {
                                    await MainActor.run {
                                        weeklyGoal.content = summary
                                        try? modelContext.save()
                                    }
                                }
                                await MainActor.run {
                                    isSummarizingWeek = false
                                }
                            }
                        } label: {
                            if isSummarizingWeek {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.indigo)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSummarizingWeek)

                        Image(systemName: "pencil.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if weeklyGoal.content.isEmpty {
                        Text(L10n.tapToSetWeek)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        Text(isWeekTranslated ? (translatedWeekContent ?? weeklyGoal.content) : weeklyGoal.content)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Translation button pinned to bottom-right corner
            if !weeklyGoal.content.isEmpty {
                Button {
                    toggleWeekTranslation()
                } label: {
                    if isTranslatingWeek {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.indigo)
                    } else {
                        Image(systemName: isWeekTranslated ? "character.bubble.fill" : "character.bubble")
                            .font(.caption2)
                            .foregroundStyle(.indigo.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Month Focus Card

    private var monthFocusCard: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                editingGoal = monthlyGoal
                editingContent = monthlyGoal.content
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.purple)
                        Text(L10n.thisMonthFocus)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()

                        // AI Summarize button
                        Button {
                            isSummarizingMonth = true
                            let relevantTasks = tasksForPeriod("Monthly")
                            Task {
                                if let summary = try? await AIManager().summarizeFocus(
                                    periodLabel: "month",
                                    tasks: relevantTasks,
                                    language: language
                                ) {
                                    await MainActor.run {
                                        monthlyGoal.content = summary
                                        try? modelContext.save()
                                    }
                                }
                                await MainActor.run {
                                    isSummarizingMonth = false
                                }
                            }
                        } label: {
                            if isSummarizingMonth {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.purple)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSummarizingMonth)

                        Image(systemName: "pencil.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if monthlyGoal.content.isEmpty {
                        Text(L10n.tapToSetMonth)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        Text(isMonthTranslated ? (translatedMonthContent ?? monthlyGoal.content) : monthlyGoal.content)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Translation button pinned to bottom-right corner
            if !monthlyGoal.content.isEmpty {
                Button {
                    toggleMonthTranslation()
                } label: {
                    if isTranslatingMonth {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.purple)
                    } else {
                        Image(systemName: isMonthTranslated ? "character.bubble.fill" : "character.bubble")
                            .font(.caption2)
                            .foregroundStyle(.purple.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Dream Board Section

    private var dreamBoardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.dreamBoard)
                    .font(.headline)
                Spacer()
                Button {
                    showDreamEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Edit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.purple)
                }
            }

            if dreamImages.isEmpty && dreamText.isEmpty {
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.25), Color.indigo.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(L10n.dreamBoardHint)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                .frame(minHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // Display dream board content
                VStack(spacing: 12) {
                    if !dreamImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dreamImages.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: dreamImages[index].imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 200, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    }
                                }
                            }
                        }
                    }

                    if !dreamText.isEmpty {
                        Text(dreamText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear(perform: loadDreamBoard)
    }

    // MARK: Dream Editor Sheet

    private var dreamEditorSheet: some View {
        NavigationStack {
            DreamEditorContent(
                selectedPhotoItems: $selectedPhotoItems,
                dreamImages: $dreamImages,
                dreamText: $dreamText,
                loadSelectedPhotos: { items in
                    Task {
                        for item in items {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    dreamImages.append(DreamImageData(id: UUID().uuidString + ".jpg", imageData: data))
                                }
                            }
                        }
                        await MainActor.run {
                            selectedPhotoItems = []
                        }
                    }
                }
            )
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.dreamBoard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        showDreamEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        saveDreamBoard()
                        showDreamEditor = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Goal Edit Sheet

    private func goalEditSheet(goal: PeriodGoal) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextEditor(text: $editingContent)
                    .font(.system(.body, design: .default))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .frame(minHeight: 200)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button {
                        isSummarizing = true
                        Task {
                            let periodLabel = goal.type == "Weekly" ? "week" : "month"
                            let relevantTasks = tasksForPeriod(goal.type)
                            if let summary = try? await AIManager().summarizeFocus(
                                periodLabel: periodLabel,
                                tasks: relevantTasks,
                                language: language
                            ) {
                                await MainActor.run {
                                    editingContent = summary
                                }
                            }
                            isSummarizing = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isSummarizing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Image(systemName: "sparkles")
                            Text(isSummarizing ? L10n.thinking : L10n.aiSummarize)
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(isSummarizing)
                }
                .padding(.horizontal)

                Spacer()
            }
            .contentShape(Rectangle())
            .dismissKeyboardOnTap()
            .padding(.top)
            .navigationTitle(goal.type == "Weekly" ? L10n.weekFocusSheet : L10n.monthFocusSheet)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        goal.content = editingContent
                        try? modelContext.save()
                        editingGoal = nil
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        editingGoal = nil
                    }
                }
            }
        }
    }

    // MARK: Translation

    private func toggleSummaryTranslation() {
        if isSummaryTranslated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSummaryTranslated = false
            }
            return
        }
        guard let original = aiSummary else { return }
        let targetLang = language == "zh-Hans" ? "en" : "zh-Hans"
        isTranslatingSummary = true
        Task {
            do {
                let result = try await AIManager().translate(text: original, to: targetLang)
                await MainActor.run {
                    translatedSummary = result
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSummaryTranslated = true
                    }
                }
            } catch {
                await MainActor.run {
                    // Toggle back on failure
                }
            }
            await MainActor.run {
                isTranslatingSummary = false
            }
        }
    }

    private func toggleWeekTranslation() {
        if isWeekTranslated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isWeekTranslated = false
            }
            return
        }
        let original = weeklyGoal.content
        guard !original.isEmpty else { return }
        let targetLang = language == "zh-Hans" ? "en" : "zh-Hans"
        isTranslatingWeek = true
        Task {
            do {
                let result = try await AIManager().translate(text: original, to: targetLang)
                await MainActor.run {
                    translatedWeekContent = result
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isWeekTranslated = true
                    }
                }
            } catch {}
            await MainActor.run {
                isTranslatingWeek = false
            }
        }
    }

    private func toggleMonthTranslation() {
        if isMonthTranslated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isMonthTranslated = false
            }
            return
        }
        let original = monthlyGoal.content
        guard !original.isEmpty else { return }
        let targetLang = language == "zh-Hans" ? "en" : "zh-Hans"
        isTranslatingMonth = true
        Task {
            do {
                let result = try await AIManager().translate(text: original, to: targetLang)
                await MainActor.run {
                    translatedMonthContent = result
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isMonthTranslated = true
                    }
                }
            } catch {}
            await MainActor.run {
                isTranslatingMonth = false
            }
        }
    }

    // MARK: AI Summary Logic

    private func runAISummary() {
        isSummarizing = true
        aiSummary = nil
        summaryError = nil

        let studyTasks = tasks.filter { $0.taskType == .study }
        let recentSessions = Array(focusSessions.prefix(20))

        Task {
            do {
                let result = try await AIManager().summarizeAllDomains(
                    studyTasks: studyTasks,
                    focusSessions: recentSessions,
                    healthProfile: profiles.first,
                    holdings: holdings,
                    language: language
                )
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        aiSummary = result
                    }
                }
            } catch {
                await MainActor.run {
                    summaryError = error.localizedDescription
                }
            }
            await MainActor.run {
                isSummarizing = false
            }
        }
    }

    // MARK: Dream Board Persistence

    private func loadDreamBoard() {
        if let goal = goals.first(where: { $0.type == "DreamBoard" }) {
            dreamText = goal.content
            // Load images from document directory
            loadDreamImages()
        }
    }

    private func saveDreamBoard() {
        if let goal = goals.first(where: { $0.type == "DreamBoard" }) {
            goal.content = dreamText
        } else {
            let new = PeriodGoal(type: "DreamBoard", content: dreamText)
            modelContext.insert(new)
        }
        saveDreamImages()
        try? modelContext.save()
    }

    private func dreamImagesDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("DreamBoardImages")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func loadDreamImages() {
        let dir = dreamImagesDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        dreamImages = files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return DreamImageData(id: url.lastPathComponent, imageData: data)
        }
    }

    private func saveDreamImages() {
        let dir = dreamImagesDirectory()
        // Clear existing
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        // Save new images
        for image in dreamImages {
            let url = dir.appendingPathComponent(image.id)
            try? image.imageData.write(to: url)
        }
    }

    // MARK: Helpers

    private func tasksForPeriod(_ type: String) -> [LifeTask] {
        let calendar = Calendar.current
        let now = Date.now
        if type == "Weekly" {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return [] }
            return tasks.filter { $0.targetDate >= now && $0.targetDate <= weekEnd }
        } else {
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: now) else { return [] }
            return tasks.filter { $0.targetDate >= now && $0.targetDate <= monthEnd }
        }
    }

    private func parseSummaryDomains(_ text: String) -> [(title: String, content: String)] {
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
            sections.append((title: "Summary", content: text))
        }
        return sections
    }
}

// MARK: - Dream Editor Content

struct DreamEditorContent: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var dreamImages: [DreamImageData]
    @Binding var dreamText: String
    var loadSelectedPhotos: ([PhotosPickerItem]) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imagePickerSection
                textInputSection
            }
            .padding()
        }
    }

    // MARK: Image Picker

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.addImage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 6,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                    Text("Select Photos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: selectedPhotoItems) { _, items in
                loadSelectedPhotos(items)
            }

            if !dreamImages.isEmpty {
                thumbnailStrip
            }
        }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(dreamImages.enumerated()), id: \.element.id) { index, imageData in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = UIImage(data: imageData.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 90)
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dreamImages.removeAll { $0.id == imageData.id }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                        .padding(4)
                    }
                }
            }
        }
    }

    // MARK: Text Input

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Vision")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextEditor(text: $dreamText)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 150)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Dream Image Data

struct DreamImageData: Identifiable {
    let id: String
    let imageData: Data
}
