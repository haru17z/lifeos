import Foundation
import SwiftData

@Model
final class SleepEntry {
    var id: UUID
    var date: Date
    var hoursSlept: Double
    var qualityComment: String?

    init(
        id: UUID = UUID(),
        date: Date = Date.now,
        hoursSlept: Double = 0,
        qualityComment: String? = nil
    ) {
        self.id = id
        self.date = date
        self.hoursSlept = hoursSlept
        self.qualityComment = qualityComment
    }
}
