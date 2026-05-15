import Foundation
import SwiftData

// MARK: - PeriodGoal Model

@Model
final class PeriodGoal {
    var id: UUID
    var type: String
    var content: String

    init(
        id: UUID = UUID(),
        type: String,
        content: String = ""
    ) {
        self.id = id
        self.type = type
        self.content = content
    }
}
