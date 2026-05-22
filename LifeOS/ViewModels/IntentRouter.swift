import Foundation
import SwiftUI
import SwiftData
import Observation

// MARK: - IntentRouter

/// Centralized NLP orchestration layer.
/// Accepts raw natural-language input, communicates with the LLM,
/// executes database mutations, and returns user-facing results.
///
/// Injected via `.environment(router)` at the App level so all views
/// share one entry point for AI-powered actions.
@Observable
final class IntentRouter {

    private let aiManager = AIManager()

    // MARK: - Public API

    /// Process a natural-language input string. The router sends it to the LLM,
    /// executes the resulting mutations on the provided `ModelContext`, and
    /// returns a summary the caller can display.
    ///
    /// - Parameters:
    ///   - input: The raw user text (any language).
    ///   - modelContext: The SwiftData context for persistence.
    ///   - tasks: All existing tasks (for update/delete matching).
    ///   - holdings: All existing holdings (for finance duplicate detection).
    /// - Returns: An `IntentResult` that the view can use to update its UI.
    func process(
        input: String,
        modelContext: ModelContext,
        tasks: [LifeTask] = [],
        holdings: [Holding] = []
    ) async throws -> IntentResult {
        let responses = try await aiManager.parseInput(text: input, existingTasks: tasks)

        var messages: [String] = []
        var createdTaskIds: [UUID] = []
        var updatedTaskIds: [UUID] = []
        var deletedTaskIds: [UUID] = []
        var financeMessages: [String] = []
        var healthMessages: [String] = []
        var clarifyQuestion: String?

        for response in responses {
            switch response {
            case .create(let data):
                let task = LifeTask(
                    title: data.title,
                    startTime: data.startTime,
                    endTime: data.endTime,
                    targetDate: data.targetDate,
                    timeDisplay: data.timeDisplay,
                    location: data.location,
                    notes: data.notes,
                    taskType: data.taskType,
                    isExactTime: data.isExactTime,
                    exactStartTime: data.exactStartTime,
                    exactEndTime: data.exactEndTime,
                    pomodoroSets: data.pomodoroSets
                )
                modelContext.insert(task)
                try? modelContext.save()
                createdTaskIds.append(task.id)
                messages.append("Created: \(task.title)")

            case .update(let taskId, let data):
                guard let existing = tasks.first(where: { $0.id == taskId }) else { continue }
                existing.title = data.title
                existing.startTime = data.startTime
                existing.endTime = data.endTime
                existing.targetDate = data.targetDate
                existing.timeDisplay = data.timeDisplay
                existing.location = data.location
                existing.notes = data.notes
                existing.taskType = data.taskType
                existing.isExactTime = data.isExactTime
                existing.exactStartTime = data.exactStartTime
                existing.exactEndTime = data.exactEndTime
                existing.pomodoroSets = data.pomodoroSets
                try? modelContext.save()
                updatedTaskIds.append(taskId)
                messages.append("Updated: \(data.title)")

            case .delete(let taskId):
                guard let existing = tasks.first(where: { $0.id == taskId }) else { continue }
                modelContext.delete(existing)
                try? modelContext.save()
                deletedTaskIds.append(taskId)
                messages.append("Deleted task")

            case .clarify(let question):
                clarifyQuestion = question

            case .finance(let data):
                let result = executeFinanceAction(data, holdings: holdings, modelContext: modelContext)
                if let msg = result { financeMessages.append(msg) }

            case .health(let data):
                let result = executeHealthAction(data, modelContext: modelContext)
                if let msg = result { healthMessages.append(msg) }
            }
        }

        return IntentResult(
            messages: messages + financeMessages + healthMessages,
            createdTaskIds: createdTaskIds,
            updatedTaskIds: updatedTaskIds,
            deletedTaskIds: deletedTaskIds,
            clarifyQuestion: clarifyQuestion
        )
    }

    /// Domain-scoped finance-only processing for the finance quick-input bar.
    func processFinanceCommand(
        input: String,
        modelContext: ModelContext,
        holdings: [Holding]
    ) async throws -> String {
        let result = try await aiManager.parseFinanceCommand(text: input, holdings: holdings)

        switch result.action {
        case "add":
            let ticker = (result.ticker ?? "").uppercased()
            let name = result.name ?? ticker
            let invested = result.amountInvested ?? 0
            let value = result.currentValue ?? invested
            upsertHolding(ticker: ticker, name: name, amountInvested: invested, currentValue: value, holdings: holdings, modelContext: modelContext)
            logTransaction(ticker: ticker, action: "add", detail: "+$\(String(format: "%.0f", invested)) (Finance tab)", modelContext: modelContext)
            return "Added \(ticker) (\(name)) — $\(String(format: "%.0f", invested))"

        case "update":
            guard let ticker = result.ticker?.uppercased(),
                  let existing = holdings.first(where: { $0.ticker.uppercased() == ticker }),
                  let newPrice = result.currentValue else {
                return "Holding not found. Check the ticker symbol."
            }
            existing.updateDailyPrice(to: newPrice)
            try? modelContext.save()
            logTransaction(ticker: ticker, action: "update", detail: "Price → $\(String(format: "%.2f", newPrice)) (Finance tab)", modelContext: modelContext)
            return "Updated \(ticker) to $\(String(format: "%.2f", newPrice))"

        case "delete":
            guard let ticker = result.ticker?.uppercased(),
                  let existing = holdings.first(where: { $0.ticker.uppercased() == ticker }) else {
                return "Holding not found."
            }
            modelContext.delete(existing)
            try? modelContext.save()
            logTransaction(ticker: ticker, action: "delete", detail: "Position closed (Finance tab)", modelContext: modelContext)
            return "Removed \(ticker)"

        case "chat":
            return result.message ?? "How can I help with your portfolio?"

        default:
            return result.message ?? "I didn't understand that command."
        }
    }

    // MARK: - Private Helpers

    private func executeHealthAction(
        _ data: HealthCommandResult,
        modelContext: ModelContext
    ) -> String? {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profiles = try? modelContext.fetch(descriptor),
              let profile = profiles.first else {
            return "No health profile found. Set up your profile in the Health tab first."
        }

        switch data.action {
        case "update_weight":
            guard let rawWeight = data.weightKg,
                  !rawWeight.isNaN, !rawWeight.isInfinite,
                  rawWeight >= 20, rawWeight <= 500 else {
                return "Invalid weight value. Must be between 20-500 kg."
            }
            let newWeight = (rawWeight * 10).rounded() / 10
            let oldWeight = profile.weightKg
            let weightDelta = (newWeight - oldWeight * 10).rounded() / 10
            profile.weightKg = newWeight
            profile.yesterdayWeightDelta = weightDelta
            try? modelContext.save()
            let direction = weightDelta < 0 ? "lost" : (weightDelta > 0 ? "gained" : "maintained")
            return "Weight updated: \(String(format: "%.1f", abs(weightDelta))) kg \(direction). Current: \(String(format: "%.1f", profile.weightKg)) kg."

        case "update_delta":
            guard let rawDelta = data.deltaKg,
                  !rawDelta.isNaN, !rawDelta.isInfinite,
                  abs(rawDelta) <= 50 else {
                return "Invalid delta value. Must be between -50 and +50 kg."
            }
            let clamped = (rawDelta * 10).rounded() / 10
            let newWeight = ((profile.weightKg + clamped) * 10).rounded() / 10
            guard newWeight >= 20, newWeight <= 500 else {
                return "That would put weight outside the valid range (20-500 kg)."
            }
            profile.yesterdayWeightDelta = clamped
            profile.weightKg = newWeight
            try? modelContext.save()
            let direction = clamped < 0 ? "lost" : (clamped > 0 ? "gained" : "maintained")
            return "Delta recorded: \(String(format: "%+.1f", clamped)) kg (\(direction)). New weight: \(String(format: "%.1f", profile.weightKg)) kg."

        case "chat":
            return data.message ?? "How can I help with your health?"

        default:
            return nil
        }
    }

    private func executeFinanceAction(
        _ data: FinanceCommandResult,
        holdings: [Holding],
        modelContext: ModelContext
    ) -> String? {
        switch data.action {
        case "add":
            let ticker = (data.ticker ?? "").uppercased()
            let name = data.name ?? ticker
            let invested = data.amountInvested ?? 0
            let value = data.currentValue ?? invested
            upsertHolding(ticker: ticker, name: name, amountInvested: invested, currentValue: value, holdings: holdings, modelContext: modelContext)
            logTransaction(ticker: ticker, action: "add", detail: "+$\(String(format: "%.0f", invested)) (AI command)", modelContext: modelContext)
            return "Added \(ticker) to portfolio"

        case "update":
            guard let ticker = data.ticker?.uppercased(),
                  let existing = holdings.first(where: { $0.ticker.uppercased() == ticker }),
                  let newPrice = data.currentValue else { return nil }
            existing.updateDailyPrice(to: newPrice)
            try? modelContext.save()
            logTransaction(ticker: ticker, action: "update", detail: "Price → $\(String(format: "%.2f", newPrice)) (AI command)", modelContext: modelContext)
            return "Updated \(ticker) → $\(String(format: "%.2f", newPrice))"

        case "delete":
            guard let ticker = data.ticker?.uppercased(),
                  let existing = holdings.first(where: { $0.ticker.uppercased() == ticker }) else { return nil }
            modelContext.delete(existing)
            try? modelContext.save()
            logTransaction(ticker: ticker, action: "delete", detail: "Position closed (AI command)", modelContext: modelContext)
            return "Removed \(ticker)"

        case "chat":
            return data.message

        default:
            return nil
        }
    }

    private func logTransaction(ticker: String, action: String, detail: String, modelContext: ModelContext) {
        guard !ticker.isEmpty else { return }
        let record = TransactionRecord(
            ticker: ticker.uppercased(),
            action: action,
            detail: detail
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func upsertHolding(
        ticker: String,
        name: String,
        amountInvested: Double,
        currentValue: Double,
        holdings: [Holding],
        modelContext: ModelContext
    ) {
        guard !ticker.isEmpty, amountInvested > 0 else { return }

        if let existing = holdings.first(where: { $0.ticker.uppercased() == ticker }) {
            existing.amountInvested += amountInvested
            existing.currentValue += currentValue
            if currentValue > 0 {
                existing.currentDailyPrice = currentValue
            }
            existing.recalculatePosition()
        } else {
            let price = currentValue > 0 ? currentValue : amountInvested
            let holding = Holding(
                ticker: ticker,
                name: name,
                amountInvested: amountInvested,
                currentValue: currentValue > 0 ? currentValue : amountInvested,
                currentDailyPrice: price,
                previousClose: price,
                sharesOwned: price > 0 ? amountInvested / price : 0
            )
            modelContext.insert(holding)
            holding.recalculatePosition()
        }
        try? modelContext.save()
    }
}

// MARK: - IntentResult

struct IntentResult {
    let messages: [String]
    let createdTaskIds: [UUID]
    let updatedTaskIds: [UUID]
    let deletedTaskIds: [UUID]
    let clarifyQuestion: String?

    var hasClarification: Bool { clarifyQuestion != nil }
    var isEmpty: Bool { messages.isEmpty && clarifyQuestion == nil }
}
