import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var heightCm: Double
    var weightKg: Double
    var targetWeightKg: Double
    var age: Int
    var gender: String
    var yesterdayWeightDelta: Double

    init(
        id: UUID = UUID(),
        heightCm: Double = 170,
        weightKg: Double = 65,
        targetWeightKg: Double = 65,
        age: Int = 25,
        gender: String = "male",
        yesterdayWeightDelta: Double = 0
    ) {
        self.id = id
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.targetWeightKg = targetWeightKg
        self.age = age
        self.gender = gender
        self.yesterdayWeightDelta = yesterdayWeightDelta
    }

    var bmi: Double {
        guard heightCm > 0, weightKg > 0 else { return 0 }
        return weightKg / ((heightCm / 100) * (heightCm / 100))
    }
}
