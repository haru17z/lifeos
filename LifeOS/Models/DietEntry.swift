import Foundation
import SwiftData

@Model
final class DietEntry {
    var id: UUID
    var date: Date
    var mealText: String
    var estimatedCalories: Int?

    init(
        id: UUID = UUID(),
        date: Date = Date.now,
        mealText: String = "",
        estimatedCalories: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.mealText = mealText
        self.estimatedCalories = estimatedCalories
    }
}
