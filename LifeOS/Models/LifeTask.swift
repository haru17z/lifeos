import Foundation
import SwiftData

// MARK: - TaskType Enum

enum TaskType: String, Codable, CaseIterable {
    case study
    case health
    case finance
    case vision
    case general
}

// MARK: - LifeTask Model

@Model
final class LifeTask {
    var id: UUID
    var title: String

    @Attribute(originalName: "scheduledTime")
    var startTime: Date

    var endTime: Date?
    var targetDate: Date
    var timeDisplay: String
    var location: String?
    var notes: String?
    var taskType: TaskType
    var isCompleted: Bool

    // Hybrid time system
    var isExactTime: Bool
    var exactStartTime: Date?
    var exactEndTime: Date?

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date = Date.now,
        endTime: Date? = nil,
        targetDate: Date = Date.now,
        timeDisplay: String = "",
        location: String? = nil,
        notes: String? = nil,
        taskType: TaskType = .general,
        isCompleted: Bool = false,
        isExactTime: Bool = false,
        exactStartTime: Date? = nil,
        exactEndTime: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.targetDate = targetDate
        self.timeDisplay = timeDisplay
        self.location = location
        self.notes = notes
        self.taskType = taskType
        self.isCompleted = isCompleted
        self.isExactTime = isExactTime
        self.exactStartTime = exactStartTime
        self.exactEndTime = exactEndTime
    }
}
