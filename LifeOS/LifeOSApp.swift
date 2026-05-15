import SwiftUI
import SwiftData

@main
struct LifeOSApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([LifeTask.self, PeriodGoal.self, UserProfile.self, FinanceData.self])

        do {
            container = try ModelContainer(for: schema)
        } catch {
            print("[LifeOSApp] SwiftData migration failed — deleting old store and recreating.")
            print("[LifeOSApp] Error: \(error)")

            // Remove the old incompatible store
            if let url = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first {
                let storeURL = url.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                // Also remove WAL and SHM files
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            }

            // Recreate with fresh schema
            do {
                container = try ModelContainer(for: schema)
                print("[LifeOSApp] Fresh store created successfully.")
            } catch {
                fatalError("[LifeOSApp] Could not create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
