import Foundation

// MARK: - AI Response Types

struct ParsedTaskData {
    let title: String
    let timeDisplay: String
    let targetDate: Date
    let startTime: Date
    let endTime: Date?
    let location: String?
    let notes: String?
    let taskType: TaskType
    let isExactTime: Bool
    let exactStartTime: Date?
    let exactEndTime: Date?
}

enum AIResponse {
    case create(data: ParsedTaskData)
    case update(taskId: UUID, data: ParsedTaskData)
    case delete(taskId: UUID)
    case clarify(question: String)
}

// MARK: - Errors

enum AIManagerError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noContent
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration"
        case .networkError(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse AI response: \(error.localizedDescription)"
        case .noContent:
            return "AI returned no content in the response"
        case .invalidResponse:
            return "Server returned an invalid response structure"
        }
    }
}

// MARK: - API Request / Response Models

fileprivate struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

fileprivate struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message

        struct Message: Decodable {
            let content: String
        }
    }
}

/// Raw JSON the AI is instructed to output — now an array of actions.
fileprivate struct AIResponseJSON: Decodable {
    let actions: [Action]

    struct Action: Decodable {
        let action: String
        let taskId: String?
        let task: ParsedTask?
        let clarifyQuestion: String?
    }

    struct ParsedTask: Decodable {
        let title: String?
        let timeDisplay: String?
        let targetDate: String?
        let startTime: String?
        let endTime: String?
        let location: String?
        let notes: String?
        let taskType: String?
        let isExactTime: Bool?
        let exactStartTime: String?
        let exactEndTime: String?
    }
}

// MARK: - AIManager

final class AIManager {

    private let session: URLSession
    private let baseURL = "https://api.deepseek.com/chat/completions"
    private let model = "deepseek-chat"

    private func systemPrompt(existingTasks: [LifeTask]) -> String {
        let now = Date.now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateString = formatter.string(from: now)

        let taskContext: String
        if existingTasks.isEmpty {
            taskContext = "No existing tasks."
        } else {
            taskContext = existingTasks.map { task in
                "- id: \(task.id.uuidString) | title: \"\(task.title)\" | timeDisplay: \"\(task.timeDisplay)\" | targetDate: \(ISO8601DateFormatter().string(from: task.targetDate)) | type: \(task.taskType.rawValue)"
            }.joined(separator: "\n")
        }

        return """
You are the core parser for a Life OS app. Convert the user's natural language input into a raw, valid JSON object. DO NOT output any markdown or code blocks. ONLY output the raw JSON.

The current date and time is \(dateString).

═══ LANGUAGE RULE (CRITICAL) ═══
You MUST generate ALL string fields (title, timeDisplay, notes) in the EXACT SAME LANGUAGE as the user's input.
- User types Chinese → output Chinese. Do NOT translate Chinese to English.
- User types English → output English. Do NOT translate English to Chinese.
- Preserve the user's exact phrasing style.

═══ TITLE RULES ═══
- Title MUST be extremely concise: Verb + Noun, 4-5 words max.
- ALL additional context, conditions, qualifiers → place in "notes".
- Example: "After coffee, wear the red shirt and go jogging" → title: "Go jogging", notes: "After coffee, wear the red shirt"

═══ TIME DISPLAY ═══
- Extract "timeDisplay" EXACTLY as the user says it.
- If no time mentioned → "Anytime".

═══ HYBRID TIME SYSTEM (CRITICAL) ═══
- "isExactTime": BOOLEAN. Set true ONLY when the user specifies precise clock times.
  TRUE examples: "tomorrow 4 AM to 5 AM", "next Monday at 3:00 PM", "today 9am-10am"
  FALSE examples: "Morning", "Afternoon", "Evening", "When cherry blossoms fall", "Sometime tomorrow"
- When isExactTime is TRUE:
  * Provide "exactStartTime" and "exactEndTime" as ISO8601 datetime strings.
  * Also provide a human-readable "timeDisplay" (e.g., "4:00 AM - 5:00 AM").
- When isExactTime is FALSE:
  * Set "exactStartTime" and "exactEndTime" to null.
  * Provide the fuzzy "timeDisplay" string exactly as the user said it.
  * Still compute a reasonable "startTime" for chronological sorting.

═══ TARGET DATE ═══
- "targetDate": ISO8601 date (midnight UTC) for the task day.
- "today" → today, "tomorrow" → tomorrow, "next Monday" → compute actual date.

═══ SEQUENTIAL PARSING (CRITICAL) ═══
- If the user lists multiple tasks (e.g. "Wash clothes, then eat, then study"), you MUST return an actions array with one entry per task.
- Each distinct task gets its own action object in the array.
- If the user describes only ONE task, still return an array with one element.

═══ CRUD INTENT ═══
- "create": User wants a NEW task. Provide a full task object. Default if unclear.
- "update": User wants to CHANGE an existing task. Match from existing list by title or time. Provide taskId + full updated task object.
- "delete": User wants to REMOVE a task. Match from existing list. Provide taskId, no task object needed.
- "clarify": User gave insufficient info. Return a clarifyQuestion, no task object.

EXISTING TASKS (use these IDs for update/delete):
\(taskContext)

JSON STRUCTURE (MUST be an array):
{
  "actions": [
    {
      "action": "create|update|delete|clarify",
      "taskId": "uuid-if-update-or-delete" | null,
      "task": {
        "title": "concise title",
        "timeDisplay": "user's time expression",
        "targetDate": "ISO8601 date (midnight UTC)",
        "startTime": "ISO8601 datetime for sorting",
        "endTime": "ISO8601 datetime or null",
        "isExactTime": true or false,
        "exactStartTime": "ISO8601 datetime or null",
        "exactEndTime": "ISO8601 datetime or null",
        "location": "extracted location or null",
        "notes": "all other context and details",
        "taskType": "study|health|finance|vision|general"
      } | null,
      "clarifyQuestion": "question text" | null
    }
  ]
}
"""
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Sends the user's natural-language input to the AI.
    /// Returns an array of `AIResponse` — one per parsed action.
    func parseInput(text: String, existingTasks: [LifeTask]) async throws -> [AIResponse] {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: systemPrompt(existingTasks: existingTasks)),
                ChatCompletionRequest.Message(role: "user", content: text)
            ]
        )

        let jsonData = try JSONEncoder().encode(requestBody)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(Config.deepseekAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        let (responseData, _) = try await session.data(for: urlRequest)
        let apiResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: responseData)

        guard let choice = apiResponse.choices.first else {
            throw AIManagerError.noContent
        }

        var contentString = choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code-block wrappers
        if contentString.hasPrefix("```") {
            contentString = contentString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        print("[AIManager] RAW AI RESPONSE: \(contentString)")

        guard let contentData = contentString.data(using: .utf8) else {
            throw AIManagerError.invalidResponse
        }

        let aiResponse: AIResponseJSON
        do {
            aiResponse = try JSONDecoder().decode(AIResponseJSON.self, from: contentData)
        } catch {
            print("[AIManager] DECODING ERROR: \(error)")
            throw AIManagerError.decodingError(error)
        }

        var results: [AIResponse] = []

        for action in aiResponse.actions {
            switch action.action {
            case "create":
                guard let parsed = action.task else {
                    throw AIManagerError.invalidResponse
                }
                let data = try buildParsedData(from: parsed)
                results.append(.create(data: data))

            case "update":
                guard let taskIdString = action.taskId,
                      let taskId = UUID(uuidString: taskIdString),
                      let parsed = action.task else {
                    throw AIManagerError.invalidResponse
                }
                let data = try buildParsedData(from: parsed)
                results.append(.update(taskId: taskId, data: data))

            case "delete":
                guard let taskIdString = action.taskId,
                      let taskId = UUID(uuidString: taskIdString) else {
                    throw AIManagerError.invalidResponse
                }
                results.append(.delete(taskId: taskId))

            case "clarify":
                guard let question = action.clarifyQuestion else {
                    throw AIManagerError.invalidResponse
                }
                results.append(.clarify(question: question))

            default:
                throw AIManagerError.invalidResponse
            }
        }

        return results
    }

    /// Sends task completion data to the AI coach and returns empathetic feedback.
    func getFeedback(task: LifeTask, completion: Double, note: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let feedbackPrompt = """
You are an empathetic, pragmatic Life Coach. The user completed a task at \(Int(completion))%. Note: \(note). If completion is low, be highly comforting, tell them 'intermittent consistency is still long-termism', and suggest reducing the workload to a microscopic step next time. If high, be encouraging. Do not use grand narratives. Output ONLY a short, warm, 2-3 sentence response.
"""

        let userMessage = """
Task: \(task.title)
Type: \(task.taskType.rawValue)
Completion: \(Int(completion))%
Note: \(note)
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: feedbackPrompt),
                ChatCompletionRequest.Message(role: "user", content: userMessage)
            ]
        )

        let jsonData = try JSONEncoder().encode(requestBody)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(Config.deepseekAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        let (responseData, _) = try await session.data(for: urlRequest)
        let apiResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: responseData)

        guard let choice = apiResponse.choices.first else {
            throw AIManagerError.noContent
        }

        return choice.message.content
    }

    /// Generates a brief, philosophical focus summary based on upcoming tasks.
    func summarizeFocus(periodLabel: String, tasks: [LifeTask]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let taskList = tasks.isEmpty
            ? "No tasks planned."
            : tasks.map { "- \($0.title) (\($0.timeDisplay))" }.joined(separator: "\n")

        let prompt = """
You are a warm, philosophical life coach. Given these upcoming tasks for the \(periodLabel), generate a brief, inspiring, slightly poetic focus statement. Be warm and concise. 2-3 sentences maximum. Output ONLY the statement, no markdown, no quotes.
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
                ChatCompletionRequest.Message(role: "user", content: taskList)
            ]
        )

        let jsonData = try JSONEncoder().encode(requestBody)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(Config.deepseekAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData

        let (responseData, _) = try await session.data(for: urlRequest)
        let apiResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: responseData)

        guard let choice = apiResponse.choices.first else {
            throw AIManagerError.noContent
        }

        return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Helpers

    private func buildParsedData(from parsed: AIResponseJSON.ParsedTask) throws -> ParsedTaskData {
        // Provide sane defaults for optional fields
        let title = parsed.title ?? "Untitled"
        let timeDisplay = parsed.timeDisplay ?? "Anytime"

        let startDate: Date
        if let startStr = parsed.startTime {
            startDate = try parseISO8601Date(startStr)
        } else {
            startDate = Date.now
        }

        let targetDate: Date
        if let targetStr = parsed.targetDate {
            targetDate = try parseDateOnly(targetStr)
        } else {
            targetDate = Calendar.current.startOfDay(for: Date.now)
        }

        let endDate: Date?
        if let endStr = parsed.endTime, !endStr.isEmpty {
            endDate = try parseISO8601Date(endStr)
        } else {
            endDate = nil
        }

        let taskType = TaskType(rawValue: parsed.taskType ?? "general") ?? .general

        let isExactTime = parsed.isExactTime ?? false

        let exactStartDate: Date?
        if let exactStartStr = parsed.exactStartTime, !exactStartStr.isEmpty {
            exactStartDate = try parseISO8601Date(exactStartStr)
        } else {
            exactStartDate = nil
        }

        let exactEndDate: Date?
        if let exactEndStr = parsed.exactEndTime, !exactEndStr.isEmpty {
            exactEndDate = try parseISO8601Date(exactEndStr)
        } else {
            exactEndDate = nil
        }

        return ParsedTaskData(
            title: title,
            timeDisplay: timeDisplay,
            targetDate: targetDate,
            startTime: startDate,
            endTime: endDate,
            location: parsed.location?.isEmpty == true ? nil : parsed.location,
            notes: parsed.notes?.isEmpty == true ? nil : parsed.notes,
            taskType: taskType,
            isExactTime: isExactTime,
            exactStartTime: exactStartDate,
            exactEndTime: exactEndDate
        )
    }

    private func parseISO8601Date(_ dateString: String) throws -> Date {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: dateString) { return date }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        if let date = standardFormatter.date(from: dateString) { return date }

        let tzFormatter = ISO8601DateFormatter()
        tzFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = tzFormatter.date(from: dateString) { return date }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        if let date = dateFormatter.date(from: dateString) { return date }

        throw AIManagerError.decodingError(
            NSError(domain: "AIManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not parse ISO8601 date: \"\(dateString)\""
            ])
        )
    }

    private func parseDateOnly(_ dateString: String) throws -> Date {
        if let date = try? parseISO8601Date(dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        if let date = dateFormatter.date(from: dateString) {
            return Calendar.current.startOfDay(for: date)
        }
        throw AIManagerError.decodingError(
            NSError(domain: "AIManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not parse date: \"\(dateString)\""
            ])
        )
    }
}
