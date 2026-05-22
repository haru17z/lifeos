import SwiftUI
import SwiftData

@main
struct LifeOSApp: App {

    let container: ModelContainer
    @State private var focusEngine = FocusEngineManager()
    @State private var intentRouter = IntentRouter()

    init() {
        let schema = Schema([LifeTask.self, PeriodGoal.self, UserProfile.self, FinanceData.self, FocusSession.self, Holding.self, DietEntry.self, SleepEntry.self, MoodEntry.self, TransactionRecord.self])

        do {
            container = try ModelContainer(for: schema)
        } catch {
            print("[LifeOSApp] SwiftData migration failed — deleting old store and recreating.")
            print("[LifeOSApp] Error: \(error)")

            if let url = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first {
                let storeURL = url.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            }

            do {
                container = try ModelContainer(for: schema)
                print("[LifeOSApp] Fresh store created successfully.")
            } catch {
                fatalError("[LifeOSApp] Could not create ModelContainer: \(error)")
            }
        }

        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(focusEngine)
                .environment(intentRouter)
        }
        .modelContainer(container)
    }
}
