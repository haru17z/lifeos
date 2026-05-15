import SwiftUI

// MARK: - FeedbackModalView

struct FeedbackModalView: View {
    let task: LifeTask
    @Environment(\.dismiss) private var dismiss

    @State private var completionRate: Double = 50
    @State private var feedbackNote: String = ""
    @State private var isSubmitting = false
    @State private var aiCoachResponse: String?
    @State private var feedbackError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(task.timeDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Completion slider
                    VStack(spacing: 8) {
                        HStack {
                            Text(L10n.completionRateLabel)
                                .font(.headline)
                            Spacer()
                            Text("\(Int(completionRate))%")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        Slider(value: $completionRate, in: 0...100, step: 5)
                            .tint(completionRate > 50 ? .green : .orange)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.thoughtsExcuses)
                            .font(.headline)
                        TextField(L10n.howDidItGo, text: $feedbackNote, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .lineLimit(3...6)
                    }

                    // Submit button
                    Button(action: submitFeedback) {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Reflecting..." : "Submit to AI Coach")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(isSubmitting)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // AI Response
                    if let response = aiCoachResponse {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(.indigo)
                                Text("AI Coach")
                                    .font(.headline)
                                    .foregroundStyle(.indigo)
                            }
                            Text(response)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                    }

                    if let error = feedbackError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.taskReview)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: aiCoachResponse != nil)
        }
    }

    private func submitFeedback() {
        isSubmitting = true
        aiCoachResponse = nil
        feedbackError = nil

        Task {
            do {
                let response = try await AIManager().getFeedback(
                    task: task,
                    completion: completionRate,
                    note: feedbackNote
                )
                aiCoachResponse = response
            } catch {
                feedbackError = "Failed to get feedback: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }
}
