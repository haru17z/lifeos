import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID
    var date: Date
    var durationSeconds: Int
    var method: String
    var setsCompleted: Int
    var totalSets: Int
    var studyContent: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = Date.now,
        durationSeconds: Int = 0,
        method: String = "pomodoro",
        setsCompleted: Int = 0,
        totalSets: Int = 1,
        studyContent: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.method = method
        self.setsCompleted = setsCompleted
        self.totalSets = totalSets
        self.studyContent = studyContent
        self.notes = notes
    }
}
