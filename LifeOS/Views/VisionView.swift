import SwiftUI
import SwiftData

// MARK: - VisionView

struct VisionView: View {

    @Query(sort: \LifeTask.targetDate) private var tasks: [LifeTask]
    @Query private var goals: [PeriodGoal]
    @Environment(\.modelContext) private var modelContext

    @State private var editingGoal: PeriodGoal?
    @State private var editingContent: String = ""
    @State private var isSummarizing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weekFocusCard
                    monthFocusCard
                    dreamBoard
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.visionOverview)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingGoal) { goal in
                goalEditSheet(goal: goal)
            }
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

    // MARK: Week Focus Card

    private var weekFocusCard: some View {
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
                    Text(weeklyGoal.content)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Month Focus Card

    private var monthFocusCard: some View {
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
                    Text(monthlyGoal.content)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
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
                                tasks: relevantTasks
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

    // MARK: Dream Board

    private var dreamBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.dreamBoard)
                .font(.headline)

            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.indigo.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(L10n.dreamComingSoon)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Helpers

    private func tasksForPeriod(_ type: String) -> [LifeTask] {
        let calendar = Calendar.current
        let now = Date.now

        if type == "Weekly" {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else {
                return []
            }
            return tasks.filter { $0.targetDate >= now && $0.targetDate <= weekEnd }
        } else {
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: now) else {
                return []
            }
            return tasks.filter { $0.targetDate >= now && $0.targetDate <= monthEnd }
        }
    }
}
