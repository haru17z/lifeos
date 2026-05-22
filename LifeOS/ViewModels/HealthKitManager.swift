import Foundation
import HealthKit
import Observation

// MARK: - HealthKitManager

@Observable
final class HealthKitManager {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    var isAuthorized = false
    var stepCount: Int = 0
    var authError: String?

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authError = "HealthKit not available on this device"
            return
        }

        let readTypes: Set<HKObjectType> = [stepType]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)

            await MainActor.run {
                isAuthorized = true
                authError = nil
            }
        } catch {
            await MainActor.run {
                isAuthorized = false
                authError = error.localizedDescription
                print("[HealthKitManager] Authorization error: \(error)")
            }
        }
    }

    // MARK: - Step Count Fetch

    func fetchTodaySteps() async {
        if !isAuthorized {
            await requestAuthorization()
            guard isAuthorized else { return }
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        do {
            let steps = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: sum)
                }
                store.execute(query)
            }

            await MainActor.run {
                stepCount = Int(steps)
            }
        } catch {
            print("[HealthKitManager] Step fetch error: \(error)")
        }
    }

    // MARK: - Formatted String

    var stepCountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
    }
}
