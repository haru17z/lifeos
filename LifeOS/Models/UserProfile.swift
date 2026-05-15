import Foundation
import SwiftData

@Model
final class UserProfile {
    var heightCm: Double
    var weightKg: Double
    var age: Int
    var gender: String

    init(
        heightCm: Double = 170,
        weightKg: Double = 65,
        age: Int = 25,
        gender: String = "other"
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.age = age
        self.gender = gender
    }

    var bmi: Double {
        guard heightCm > 0, weightKg > 0 else { return 0 }
        return weightKg / ((heightCm / 100) * (heightCm / 100))
    }
}
