import SwiftUI

// MARK: - TaskCardView

struct TaskCardView: View {
    let task: LifeTask
    var onLocationTap: ((String) -> Void)?

    @State private var showMapSheet = false

    var body: some View {
        HStack(spacing: 14) {
            // Type indicator bar
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(taskTypeColor)
                .frame(width: 5)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(task.timeDisplay)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    if let location = task.location, !location.isEmpty {
                        Button {
                            onLocationTap?(location)
                        } label: {
                            Label(location, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Badge
            Text(task.taskType.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(taskTypeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(taskTypeColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var taskTypeColor: Color {
        switch task.taskType {
        case .study:    return .blue
        case .health:   return .green
        case .finance:  return .orange
        case .vision:   return .purple
        case .general:  return .gray
        }
    }
}
