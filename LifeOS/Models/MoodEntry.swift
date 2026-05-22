import Foundation
import SwiftData

@Model
final class MoodEntry {
    var id: UUID
    var date: Date
    var emoji: String
    var score: Int

    init(
        id: UUID = UUID(),
        date: Date = Date.now,
        emoji: String = "😐",
        score: Int = 3
    ) {
        self.id = id
        self.date = date
        self.emoji = emoji
        self.score = score
    }

    static let emojiScale: [(emoji: String, score: Int, labelEn: String, labelZh: String)] = [
        ("😄", 5, "Great", "很好"),
        ("🙂", 4, "Good", "不错"),
        ("😐", 3, "Okay", "一般"),
        ("😕", 2, "Low", "低落"),
        ("😭", 1, "Awful", "糟糕")
    ]
}
