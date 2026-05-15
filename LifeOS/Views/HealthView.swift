import SwiftUI
import SwiftData

// MARK: - HealthView

struct HealthView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var age: Int = 25
    @State private var weightKg: Double = 65
    @State private var heightCm: Double = 170
    @State private var gender: String = "other"

    @State private var meal1: String = ""
    @State private var meal2: String = ""
    @State private var meal3: String = ""
    @State private var weightChange: Double = 0
    @State private var weightHistory: [Double] = []

    @State private var aiSuggestion: String?
    @State private var isFetchingSuggestion = false
    @State private var suggestionError: String?

    private let genders = ["male", "female", "other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    bmiSection
                    mealsSection
                    weightTrackingSection
                    aiSuggestionSection
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.health)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadData)
        }
    }

    // MARK: BMI Section

    private var bmiSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.bodyMetrics)
                .font(.headline)

            Picker(L10n.genderLabel, selection: $gender) {
                Text(L10n.male).tag("male")
                Text(L10n.female).tag("female")
                Text(L10n.other).tag("other")
            }
            .pickerStyle(.segmented)

            HStack {
                Text(L10n.ageLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField(L10n.ageLabel, value: $age, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(L10n.weightLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("kg", value: $weightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("kg")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(L10n.heightLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("cm", value: $heightCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("cm")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            let bmi = calculatedBMI
            HStack {
                Text(L10n.bmiLabel)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f", bmi))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(bmiColor(bmi))
                Text(bmiCategory(bmi))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Button(L10n.saveProfile) {
                saveProfile()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: gender) { _, _ in saveProfile() }
    }

    // MARK: Meals Section

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.dailyMeals)
                .font(.headline)

            mealField(icon: "sunrise.fill", label: L10n.breakfast, text: $meal1)
            mealField(icon: "sun.max.fill", label: L10n.lunch, text: $meal2)
            mealField(icon: "moon.fill", label: L10n.dinner, text: $meal3)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func mealField(icon: String, label: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            TextField(L10n.whatDidYouEat, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Weight Tracking

    private var weightTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.weightTracking)
                .font(.headline)

            HStack(spacing: 12) {
                TextField(L10n.weightChangeLabel, value: $weightChange, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(L10n.logLabel) {
                    if weightChange != 0 {
                        weightHistory.append(weightChange)
                        weightChange = 0
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            if !weightHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.recentChanges)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(weightHistory.indices, id: \.self) { index in
                        let change = weightHistory[index]
                        HStack {
                            Text("Entry \(index + 1):")
                                .font(.caption)
                            Text(change > 0 ? "+\(String(format: "%.1f", change)) kg" : "\(String(format: "%.1f", change)) kg")
                                .font(.caption)
                                .foregroundStyle(change > 0 ? .red : .green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: AI Suggestions

    private var aiSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.aiDietSuggestions)
                .font(.headline)

            Button(action: fetchAISuggestion) {
                HStack(spacing: 8) {
                    if isFetchingSuggestion {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isFetchingSuggestion ? L10n.thinking : L10n.getAISuggestions)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isFetchingSuggestion)

            if let suggestion = aiSuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.green)
                        Text(L10n.aiSuggestionHeader)
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    Text(suggestion)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let error = suggestionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Computed

    private var calculatedBMI: Double {
        guard heightCm > 0, weightKg > 0 else { return 0 }
        return weightKg / ((heightCm / 100) * (heightCm / 100))
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "(Underweight)"
        case 18.5..<25: return "(Normal)"
        case 25..<30: return "(Overweight)"
        default: return "(Obese)"
        }
    }

    // MARK: Persistence

    private func loadData() {
        if let profile = profiles.first {
            age = profile.age
            weightKg = profile.weightKg
            heightCm = profile.heightCm
            gender = profile.gender
        }
    }

    private func saveProfile() {
        if let profile = profiles.first {
            profile.age = age
            profile.weightKg = weightKg
            profile.heightCm = heightCm
            profile.gender = gender
        } else {
            let new = UserProfile(
                heightCm: heightCm,
                weightKg: weightKg,
                age: age,
                gender: gender
            )
            modelContext.insert(new)
        }
    }

    private func fetchAISuggestion() {
        isFetchingSuggestion = true
        aiSuggestion = nil
        suggestionError = nil

        let bmi = calculatedBMI
        let userData = """
Age: \(age), Gender: \(gender), Weight: \(weightKg)kg, Height: \(heightCm)cm, BMI: \(String(format: "%.1f", bmi)).
Meals today: Breakfast: \(meal1.isEmpty ? "not logged" : meal1), Lunch: \(meal2.isEmpty ? "not logged" : meal2), Dinner: \(meal3.isEmpty ? "not logged" : meal3).
Recent weight changes: \(weightHistory.isEmpty ? "none" : weightHistory.map { String(format: "%.1f kg", $0) }.joined(separator: ", ")).
"""

        Task {
            do {
                guard let url = URL(string: "https://api.deepseek.com/chat/completions") else { return }

                let prompt = """
You are a helpful health coach. Based on the user's profile data, provide a short, practical diet and exercise suggestion. Focus on actionable advice. Keep it under 4 sentences. Do not use grand narratives or make medical claims.
"""

                let body = ChatCompletionSimpleRequest(
                    model: "deepseek-chat",
                    messages: [
                        ChatCompletionSimpleRequest.Message(role: "system", content: prompt),
                        ChatCompletionSimpleRequest.Message(role: "user", content: userData)
                    ]
                )

                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue("Bearer \(Config.deepseekAPIKey)", forHTTPHeaderField: "Authorization")
                urlRequest.httpBody = try JSONEncoder().encode(body)

                let (data, _) = try await URLSession.shared.data(for: urlRequest)
                let apiResponse = try JSONDecoder().decode(ChatCompletionSimpleResponse.self, from: data)

                await MainActor.run {
                    aiSuggestion = apiResponse.choices.first?.message.content
                }
            } catch {
                await MainActor.run {
                    suggestionError = "Failed to get suggestions: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isFetchingSuggestion = false
            }
        }
    }
}

// MARK: - Simple Chat Completion (for Health AI)

private struct ChatCompletionSimpleRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatCompletionSimpleResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message

        struct Message: Decodable {
            let content: String
        }
    }
}
