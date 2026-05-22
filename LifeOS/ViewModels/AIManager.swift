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
    let pomodoroSets: Int
}

enum AIResponse {
    case create(data: ParsedTaskData)
    case update(taskId: UUID, data: ParsedTaskData)
    case delete(taskId: UUID)
    case clarify(question: String)
    case finance(data: FinanceCommandResult)
    case health(data: HealthCommandResult)
}

// MARK: - Finance Command Result

struct FinanceCommandResult: Decodable {
    let action: String
    let ticker: String?
    let name: String?
    let amountInvested: Double?
    let currentValue: Double?
    let message: String?
}

// MARK: - Health Command Result

struct HealthCommandResult: Decodable {
    let action: String
    let weightKg: Double?
    let deltaKg: Double?
    let message: String?
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
        let finance: FinanceActionData?
        let health: HealthActionData?
    }

    struct FinanceActionData: Decodable {
        let action: String
        let ticker: String?
        let name: String?
        let amountInvested: Double?
        let currentValue: Double?
        let message: String?
    }

    struct HealthActionData: Decodable {
        let action: String
        let weightKg: Double?
        let deltaKg: Double?
        let message: String?
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
        let pomodoroSets: Int?
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

        // Compute local timezone offset for the LLM (e.g., "+08:00")
        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        let tzHours = abs(secondsFromGMT) / 3600
        let tzMinutes = (abs(secondsFromGMT) % 3600) / 60
        let tzSign = secondsFromGMT >= 0 ? "+" : "-"
        let tzOffset = String(format: "%@%02d:%02d", tzSign, tzHours, tzMinutes)

        let taskContext: String
        if existingTasks.isEmpty {
            taskContext = "No existing tasks."
        } else {
            taskContext = existingTasks.map { task in
                "- id: \(task.id.uuidString) | title: \"\(task.title)\" | timeDisplay: \"\(task.timeDisplay)\" | targetDate: \(ISO8601DateFormatter().string(from: task.targetDate)) | type: \(task.taskType.rawValue)"
            }.joined(separator: "\n")
        }

        return """
You are the core parser for a Life OS app. Convert the user's natural language input into a raw, valid JSON object. DO NOT output any markdown, code blocks, or conversational text. ONLY output the raw JSON. Any non-JSON output will cause a system error.

The current date and time is \(dateString).
The user's local timezone offset is \(tzOffset).

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

═══ TIMEZONE RULE (CRITICAL) ═══
- The user's timezone offset is \(tzOffset). You MUST append this offset to EVERY datetime string you generate.
- Example: "2026-05-17T20:00:00\(tzOffset)" for 8:00 PM local time.
- NEVER output timezone-naive datetime strings (no bare "2026-05-17T20:00:00"). Always include the offset.
- If the user says "tomorrow 8pm", and the timezone is \(tzOffset), the exactStartTime MUST be "2026-05-17T20:00:00\(tzOffset)".

═══ FUZZY TIME BLOCK MAPPING (CRITICAL) ═══
When the user uses fuzzy time-of-day expressions WITHOUT a specific clock time, map them to these blocks:
- "Morning", "Morning hours", "AM" → 09:00 to 12:00
- "Afternoon", "Afternoon hours", "PM" → 14:00 to 18:00
- "Evening", "Night", "Tonight" → 19:00 to 21:00
- "Noon", "Lunch", "Midday" → 12:00 to 13:00
- "Early morning", "Dawn" → 06:00 to 09:00
- "Late night" → 22:00 to 23:59

For fuzzy times, set "isExactTime": false, but still compute "startTime" and "endTime" from the mapped block for chronological sorting. Set "timeDisplay" to the user's original fuzzy expression (e.g., "Morning").

═══ TIME PRECISION RULES (CRITICAL) ═══
- "isExactTime": BOOLEAN. Set true when the user specifies precise clock times.
  TRUE examples: "tomorrow 4 AM to 5 AM", "next Monday at 3:00 PM", "today 9am-10am", "8 AM", "study at 7pm"
  FALSE examples: "Morning", "Afternoon", "Evening", "When cherry blossoms fall", "Sometime tomorrow"
- When isExactTime is TRUE AND the user specifies BOTH start AND end times:
  * Provide "exactStartTime" AND "exactEndTime" as ISO8601 datetime strings WITH the \(tzOffset) offset.
  * Set a human-readable "timeDisplay" (e.g., "4:00 AM - 5:00 AM").
  * For study tasks: calculate "pomodoroSets" = ceiling((endTimeMinutes - startTimeMinutes) / 30). Min 1, max 32.
- When isExactTime is TRUE but ONLY a start time is given (e.g., "8 AM", "tomorrow 3pm", "go jogging at 7"):
  * Provide ONLY "exactStartTime" — set "exactEndTime" to null. Do NOT invent a duration.
  * This is a point-in-time marker, not a time block. The user did not ask for a duration.
  * Set "timeDisplay" to the user's time expression (e.g., "8:00 AM").
  * For study tasks without an end time: set "pomodoroSets" to 0 (the app will use a sensible default).
- When isExactTime is FALSE:
  * Set "exactStartTime" and "exactEndTime" to null.
  * Provide the fuzzy "timeDisplay" string exactly as the user said it.
  * Still compute a reasonable "startTime" for chronological sorting using the fuzzy time block map above.

═══ TARGET DATE ═══
- "targetDate": ISO8601 date (midnight UTC) for the task day.
- "today" → today, "tomorrow" → tomorrow, "next Monday" → compute actual date.

═══ CHINESE HOLIDAY DATE RESOLUTION ═══
When the user references Chinese holidays, resolve them to the exact calendar date:
- 元旦 (New Year) → January 1 of the current year
- 春节/过年 (Chinese New Year) → February 17, 2026 / January 29, 2025
- 清明节 (Qingming) → April 5, 2026 / April 4, 2025
- 劳动节/五一 (Labor Day) → May 1
- 端午节 (Dragon Boat) → June 19, 2026 / June 7, 2025
- 中秋节 (Mid-Autumn) → October 4, 2026 / September 29, 2025
- 国庆节/十一 (National Day) → October 1
- 圣诞/圣诞节 → December 25
Use the current year when resolving. Respect the timezone offset.

═══ FUZZY DATE PRESERVATION ═══
- If the user uses expressions that CANNOT be mapped to an exact calendar date, preserve them verbatim in "timeDisplay".
- Examples: "下周" → timeDisplay: "下周", "朋友叫我参加派对的时候" → timeDisplay: "朋友叫我参加派对的时候"
- For fuzzy dates, set "targetDate" to today and "isExactTime" to false.

═══ SEQUENTIAL PARSING (CRITICAL) ═══
- If the user lists multiple tasks (e.g. "Wash clothes, then eat, then study"), you MUST return an actions array with one entry per task.
- Each distinct task gets its own action object in the array.
- If the user describes only ONE task, still return an array with one element.

═══ CRUD INTENT ═══
- "create": User wants a NEW task. Provide a full task object. Default if unclear.
- "update": User wants to CHANGE an existing task. Match from existing list by title or time. Provide taskId + full updated task object.
- "delete": User wants to REMOVE a task. Match from existing list. Provide taskId, no task object needed.
- "clarify": User gave insufficient info. Return a clarifyQuestion, no task object.
- "finance": Use when the user is making a PAST-TENSE or PRESENT-TENSE financial statement that records a transaction or portfolio action. Do NOT create a schedule task for these. Instead, use the "finance" action type.

═══ HEALTH INTENT ROUTING (CRITICAL) ═══
You MUST detect health/body-metric intents and route them as "health" actions, NOT as "create" tasks.

Health triggers (use "action": "health"):
- Weight updates: "I weigh 70 kg", "My weight is now 150 Jin", "Currently 65kg"
- Weight delta: "I lost 5 Jin yesterday", "Gained 2 kg this week", "Down 0.5 kg since Monday"
- General health chat: "How's my health looking?", "Am I on track?"

Health action sub-types (in the "health" object):
- "update_weight": User reported their current weight. Extract weightKg (in kg, ALWAYS convert to metric kg).
- "update_delta": User reported a weight change. Extract deltaKg (positive=weight gain, negative=weight loss).
- "chat": General health question. Provide a helpful message.

CRITICAL - Unit Conversion:
- 1 斤 (Jin/Chinese catty) = 0.5 kg. ALWAYS convert Jin to kg.
- "5 Jin" → 2.5 kg. "150 Jin" → 75 kg.
- "10 斤" → 5.0 kg.
- If the user says "斤", "Jin", or "catty", apply the 0.5× conversion factor.
- Pounds (lbs): 1 lb ≈ 0.4536 kg. Convert accordingly.
- Stones (st): 1 st = 6.35029 kg. Convert accordingly.
- Always output weightKg and deltaKg in METRIC kg regardless of the input unit.

Health rules:
- If the user reports current weight AND a delta, produce ONE health action with both fields populated.
- Do NOT create schedule tasks for health metric reports.
- Do NOT backdate — always use the current date.

═══ FINANCE INTENT ROUTING (CRITICAL) ═══
You MUST detect finance/portfolio intents and route them as "finance" actions, NOT as "create" tasks.

Finance triggers (use "action": "finance"):
- PAST TENSE investing: "I invested $500 in Apple", "Bought $1000 of Bitcoin yesterday", "Just put $2000 into NVDA"
- PRESENT TENSE portfolio updates: "My Apple shares are now worth $6000", "Bitcoin dropped to $40k"
- Portfolio queries: "What's my portfolio look like?", "How much do I have in tech stocks?"
- Selling: "Sold all my Tesla", "Exited my Bitcoin position"

Finance action sub-types (in the "finance" object):
- "add": User bought/invested in something NEW. Extract ticker, name, amountInvested, currentValue.
- "update": User's existing holding changed value. Extract ticker and currentValue.
- "delete": User sold/exited a position. Extract ticker.
- "chat": General portfolio question. Provide a helpful message.

Finance rules:
- Ticker ALWAYS uppercased (AAPL, BTC, TSLA).
- Infer ticker from company name: Apple→AAPL, Microsoft→MSFT, Google→GOOGL, Amazon→AMZN, Tesla→TSLA, Nvidia→NVDA, Meta→META, Netflix→NFLX, Bitcoin→BTC, Ethereum→ETH.
- If user says "bought $X of Y" without current value, set currentValue equal to amountInvested.
- Do NOT create schedule tasks for finance statements. These are portfolio records, not calendar items.
- Past-tense time references ("yesterday", "last week") with finance intents should be treated as portfolio records with the current date — do not backdate.

EXISTING TASKS (use these IDs for update/delete):
\(taskContext)

JSON STRUCTURE (MUST be a valid JSON object with an "actions" array — no other output allowed):
{
  "actions": [
    {
      "action": "create|update|delete|clarify|finance|health",
      "taskId": "uuid-if-update-or-delete" | null,
      "task": {
        "title": "concise title",
        "timeDisplay": "user's time expression",
        "targetDate": "ISO8601 date (midnight UTC)",
        "startTime": "ISO8601 datetime with offset",
        "endTime": "ISO8601 datetime with offset or null",
        "isExactTime": true or false,
        "exactStartTime": "ISO8601 datetime with offset or null",
        "exactEndTime": "ISO8601 datetime with offset or null",
        "location": "extracted location or null",
        "notes": "all other context and details",
        "taskType": "study|health|finance|vision|general",
        "pomodoroSets": 0 or calculated number
      } | null,
      "clarifyQuestion": "question text" | null,
      "finance": {
        "action": "add|update|delete|chat",
        "ticker": "AAPL" or null,
        "name": "Company name" or null,
        "amountInvested": number or null,
        "currentValue": number or null,
        "message": "response text" or null
      } | null,
      "health": {
        "action": "update_weight|update_delta|chat",
        "weightKg": number or null,
        "deltaKg": number or null,
        "message": "response text" or null
      } | null
    }
  ]
}
"""
    }

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
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

            case "finance":
                guard let finance = action.finance else {
                    throw AIManagerError.invalidResponse
                }
                let result = FinanceCommandResult(
                    action: finance.action,
                    ticker: finance.ticker,
                    name: finance.name,
                    amountInvested: finance.amountInvested,
                    currentValue: finance.currentValue,
                    message: finance.message
                )
                results.append(.finance(data: result))

            case "health":
                guard let health = action.health else {
                    throw AIManagerError.invalidResponse
                }
                let result = HealthCommandResult(
                    action: health.action,
                    weightKg: health.weightKg,
                    deltaKg: health.deltaKg,
                    message: health.message
                )
                results.append(.health(data: result))

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
    func summarizeFocus(periodLabel: String, tasks: [LifeTask], language: String = "en") async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let taskList = tasks.isEmpty
            ? "No tasks planned."
            : tasks.map { "- \($0.title) (\($0.timeDisplay))" }.joined(separator: "\n")

        let langName = language == "zh-Hans" ? "Simplified Chinese (zh-CN)" : "English"
        let prompt = """
You are a warm, philosophical life coach. Given these upcoming tasks for the \(periodLabel), generate a brief, inspiring, slightly poetic focus statement. Be warm and concise. 2-3 sentences maximum. Output ONLY the statement, no markdown, no quotes.

═══ LANGUAGE RULE (CRITICAL) ═══
You MUST output the summary in \(langName).
- Output ONLY in \(langName). Do NOT translate or mix languages.
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

    /// Generates a comprehensive health analysis: body evaluation + lifestyle advice.
    func analyzeHealth(
        gender: String,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        targetWeightKg: Double,
        yesterdayDelta: Double = 0,
        targetGap: Double = 0,
        language: String = "en"
    ) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let bmi = heightCm > 0 ? weightKg / ((heightCm / 100) * (heightCm / 100)) : 0

        let userData = """
Gender: \(gender), Age: \(age), Height: \(String(format: "%.1f", heightCm))cm, \
Current Weight: \(String(format: "%.1f", weightKg))kg, \
Target Weight: \(String(format: "%.1f", targetWeightKg))kg, \
BMI: \(String(format: "%.1f", bmi)), \
Yesterday Weight Change: \(String(format: "%+.1f", yesterdayDelta))kg, \
Target Gap: \(String(format: "%.1f", targetGap))kg \(targetGap > 0 ? "to lose" : (targetGap < 0 ? "over target" : "at target"))
"""

        let langName = language == "zh-Hans" ? "Simplified Chinese (zh-CN)" : "English"
        let prompt = """
You are a certified health analyst and lifestyle coach. Given the user's body metrics, generate a comprehensive evaluation.

Structure your response in these sections, using plain text (no markdown):

BODY COMPOSITION ANALYSIS
- Brief assessment of current BMI, weight status, and body composition

TARGET WEIGHT PATHWAY
- Realistic timeline estimate to reach target weight
- Key milestone markers

NUTRITION GUIDANCE
- Caloric target range recommendation
- Macronutrient split suggestion
- Specific food recommendations

EXERCISE PROTOCOL
- Weekly exercise structure (cardio + resistance)
- Specific exercise suggestions matching their profile

LIFESTYLE OPTIMIZATION
- Sleep, stress management, hydration recommendations

CRITICAL: Be specific with numbers (calories, grams, minutes, days). Do NOT make medical claims or diagnose conditions. Keep each section 2-4 sentences. Output ONLY the analysis text, no markdown formatting.

═══ LANGUAGE RULE (CRITICAL) ═══
You MUST output the entire analysis in \(langName).
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
                ChatCompletionRequest.Message(role: "user", content: userData)
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

    /// Generates a multi-domain summary covering Study, Health, and Finance independently.
    func summarizeAllDomains(
        studyTasks: [LifeTask],
        focusSessions: [FocusSession],
        healthProfile: UserProfile?,
        holdings: [Holding],
        language: String = "en"
    ) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        var domainContext = ""

        // Study domain
        if studyTasks.isEmpty {
            domainContext += "STUDY: No study tasks planned.\n"
        } else {
            domainContext += "STUDY TASKS:\n"
            for t in studyTasks {
                domainContext += "- \(t.title) (\(t.timeDisplay))\n"
            }
        }
        if focusSessions.isEmpty {
            domainContext += "FOCUS: No completed focus sessions.\n"
        } else {
            let recentSessions = focusSessions.prefix(10)
            let totalFocusSeconds = recentSessions.reduce(0) { $0 + $1.durationSeconds }
            domainContext += "FOCUS: \(recentSessions.count) recent sessions, \(totalFocusSeconds / 60) total minutes.\n"
        }

        // Health domain
        if let profile = healthProfile {
            let bmi = profile.bmi
            let targetGap = profile.targetWeightKg - profile.weightKg
            domainContext += "HEALTH: Gender=\(profile.gender), Age=\(profile.age), "
            domainContext += "Weight=\(String(format: "%.1f", profile.weightKg))kg, "
            domainContext += "Target=\(String(format: "%.1f", profile.targetWeightKg))kg, "
            domainContext += "BMI=\(String(format: "%.1f", bmi)), "
            domainContext += "YesterdayDelta=\(String(format: "%+.1f", profile.yesterdayWeightDelta))kg, "
            domainContext += "TargetGap=\(String(format: "%.1f", targetGap))kg\n"
        } else {
            domainContext += "HEALTH: No profile data.\n"
        }

        // Finance domain
        if holdings.isEmpty {
            domainContext += "FINANCE: No holdings recorded.\n"
        } else {
            let totalInvested = holdings.reduce(0) { $0 + $1.amountInvested }
            let totalValue = holdings.reduce(0) { $0 + $1.currentValue }
            let totalPnL = totalValue - totalInvested
            domainContext += "FINANCE: \(holdings.count) holdings, "
            domainContext += "Invested=\(String(format: "%.0f", totalInvested)), "
            domainContext += "Value=\(String(format: "%.0f", totalValue)), "
            domainContext += "PnL=\(String(format: "%.0f", totalPnL))\n"
        }

        let langName = language == "zh-Hans" ? "Simplified Chinese (zh-CN)" : "English"
        let prompt = """
You are a holistic life coach. Given the user's data across Study/Focus, Health, and Finance domains, generate a concise, inspiring cross-domain summary.

Structure your response in these sections:

STUDY & FOCUS
- 1-2 sentences on study progress and focus consistency

HEALTH
- 1-2 sentences on body metrics and health trajectory

FINANCE
- 1-2 sentences on portfolio status

OVERALL
- 1 sentence holistic takeaway tying all domains together

Keep it warm and motivating. Be specific when data allows. Output ONLY the summary text, no markdown.

═══ LANGUAGE RULE (CRITICAL) ═══
You MUST output the entire summary in \(langName).
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
                ChatCompletionRequest.Message(role: "user", content: domainContext)
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

    /// Breaks down a task into tiny, easy-to-start micro-steps.
    func microStepBreakdown(task: LifeTask) async throws -> [String] {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let prompt = """
You are a compassionate productivity coach. The user is struggling with a task and needs it broken down into extremely tiny, non-intimidating micro-steps. Each step should take 5-15 minutes max. Make the first step absurdly easy (e.g., "Open the app", "Write one sentence"). Output ONLY a JSON array of strings, no markdown, no code blocks. Example: ["Step 1", "Step 2", "Step 3"]
"""

        let userMessage = """
Task: \(task.title)
Type: \(task.taskType.rawValue)
Notes: \(task.notes ?? "None")
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
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

        var content = choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```") {
            content = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = content.data(using: .utf8),
              let steps = try? JSONDecoder().decode([String].self, from: data) else {
            // Fallback: split by newlines and clean up
            return content
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
        }
        return steps
    }

    /// Parses a natural-language finance command and returns portfolio actions.
    func parseFinanceCommand(text: String, holdings: [Holding]) async throws -> FinanceCommandResult {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let holdingsContext: String
        if holdings.isEmpty {
            holdingsContext = "No existing holdings."
        } else {
            holdingsContext = holdings.map { h in
                "- \(h.ticker.uppercased()): \"\(h.name)\" | Invested: $\(String(format: "%.0f", h.amountInvested)) | Current: $\(String(format: "%.0f", h.currentValue))"
            }.joined(separator: "\n")
        }

        let prompt = """
You are a portfolio management assistant. Parse the user's natural language input into a JSON action. Output ONLY raw JSON, no markdown.

EXISTING HOLDINGS:
\(holdingsContext)

JSON STRUCTURE:
{
  "action": "add" | "update" | "delete" | "chat",
  "ticker": "AAPL" or null,
  "name": "Company name" or null,
  "amountInvested": number or null,
  "currentValue": number or null,
  "message": "response text" or null
}

RULES:
- "add": User wants to add a new holding. Extract ticker, name, amountInvested, currentValue.
- "update": User wants to update an existing holding (e.g., price change). Match by ticker. Provide ticker and currentValue.
- "delete": User wants to remove a holding. Match by ticker.
- "chat": General question or comment. Provide a helpful message response.
- Ticker should ALWAYS be uppercased.
- If the user says a company name without a ticker (e.g., "I bought $5000 of Apple"), infer the ticker (AAPL).
- Common ticker mapping: Apple=AAPL, Microsoft=MSFT, Google=GOOGL, Amazon=AMZN, Tesla=TSLA, Nvidia=NVDA, Meta=META, Netflix=NFLX, Berkshire=BRK.B, JPMorgan=JPM, Visa=V, Johnson=JNJ, Walmart=WMT, Procter=PG, CocaCola=KO, Disney=DIS, Nike=NKE, Salesforce=CRM, Adobe=ADBE, PayPal=PYPL, Intel=INTC, AMD=AMD, Spotify=SPOT, Uber=UBER, Airbnb=ABNB, Snowflake=SNOW, Palantir=PLTR, Coinbase=COIN.
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
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

        var content = choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```") {
            content = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = content.data(using: .utf8) else {
            throw AIManagerError.invalidResponse
        }

        return try JSONDecoder().decode(FinanceCommandResult.self, from: data)
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

        let pomodoroSets: Int
        if let aiSets = parsed.pomodoroSets, aiSets > 0 {
            pomodoroSets = min(aiSets, 32)
        } else if taskType == .study, let start = exactStartDate, let end = exactEndDate {
            let durationMinutes = Int(end.timeIntervalSince(start) / 60)
            pomodoroSets = min(max(Int(ceil(Double(durationMinutes) / 30.0)), 1), 32)
        } else if taskType == .study, exactStartDate != nil {
            // Point-in-time study task with no end — sensible default of 2 sets (1 hour)
            pomodoroSets = 2
        } else {
            pomodoroSets = 0
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
            exactEndTime: exactEndDate,
            pomodoroSets: pomodoroSets
        )
    }

    private func parseISO8601Date(_ dateString: String) throws -> Date {
        let hasTimezone = dateString.contains("+") || dateString.contains("Z") || dateString.hasSuffix("z")

        if hasTimezone {
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: dateString) { return date }

            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            if let date = standardFormatter.date(from: dateString) { return date }

            let tzFormatter = ISO8601DateFormatter()
            tzFormatter.formatOptions = [.withInternetDateTime, .withTimeZone, .withColonSeparatorInTimeZone]
            if let date = tzFormatter.date(from: dateString) { return date }
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = dateFormatter.date(from: dateString) { return date }

            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            if let date = dateFormatter.date(from: dateString) { return date }

            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SS"
            if let date = dateFormatter.date(from: dateString) { return date }

            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S"
            if let date = dateFormatter.date(from: dateString) { return date }
        }

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

    /// Translates text between English and Chinese.
    func translate(text: String, to targetLanguage: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let targetName = targetLanguage == "zh-Hans" ? "Simplified Chinese" : "English"
        let prompt = """
You are a translator. Translate the following text to \(targetName). Output ONLY the translated text. Preserve the original structure, line breaks, and formatting. Do NOT add any explanations or markdown.
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
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
        return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Estimates calories for a meal description. Returns a brief nutritional breakdown.
    func estimateCalories(mealText: String, language: String = "en") async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIManagerError.invalidURL
        }

        let langName = language == "zh-Hans" ? "Simplified Chinese" : "English"
        let prompt = """
You are a nutritionist. Given a meal description, estimate the total calories and provide a brief macronutrient breakdown. Output ONLY in \(langName). Format:
"~XXX kcal | Protein: Xg | Carbs: Xg | Fat: Xg"
Keep it concise — one line only.
"""

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(role: "system", content: prompt),
                ChatCompletionRequest.Message(role: "user", content: mealText)
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
}
