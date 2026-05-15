import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {

    @AppStorage("theme") private var theme = "system"
    @AppStorage("language") private var language = "en"
    @State private var selectedTab = 0
    @State private var isVaultDrawerOpen = false

    // AI Input
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var clarifyMessage: String?
    @State private var showClarifyAlert = false
    @Query(sort: \LifeTask.startTime) private var tasks: [LifeTask]
    @Environment(\.modelContext) private var modelContext

    @Namespace private var tabNamespace

    private var resolvedColorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Main Content ──
                VStack(spacing: 0) {
                    headerBar

                    TabView(selection: $selectedTab) {
                        ScheduleView()
                            .tag(0)

                        VisionView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    if selectedTab == 0 {
                        aiInputBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    customTabBar
                }
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
                .dismissKeyboardOnTap()

                // ── Drawer overlay ──
                if isVaultDrawerOpen {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isVaultDrawerOpen = false
                            }
                        }
                        .transition(.opacity)

                    HStack {
                        Spacer()
                        VStack {
                            Spacer().frame(height: 60)
                            DrawerMenuView(isPresented: $isVaultDrawerOpen)
                        }
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                    }
                    .transition(.move(edge: .trailing))
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(resolvedColorScheme)
        .environment(\.locale, Locale(identifier: language == "zh-Hans" ? "zh_Hans" : "en"))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isVaultDrawerOpen)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedTab)
        .alert(L10n.clarificationNeeded, isPresented: $showClarifyAlert) {
            Button(L10n.ok) {}
        } message: {
            Text(clarifyMessage ?? L10n.provideDetails)
        }
        .onAppear {
            NotificationManager.shared.requestAuthorization()
        }
    }

    // MARK: Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.lifeOS)
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)

                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isVaultDrawerOpen = true
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: AI Input Bar

    private var aiInputBar: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .padding(.leading, 4)
            }

            TextField(L10n.inputPlaceholder, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...5)
                .onSubmit(submitTask)

            Button(action: submitTask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color(.tertiaryLabel)
                            : Color.indigo
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Custom Floating Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabPillButton(index: 0, icon: "calendar.day.timeline.left", label: L10n.schedule)
            tabPillButton(index: 1, icon: "eye.fill", label: L10n.vision)
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    private func tabPillButton(index: Int, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.callout)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
            }
            .foregroundStyle(selectedTab == index ? .white : .secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background {
                if selectedTab == index {
                    Capsule()
                        .fill(Color.indigo.gradient)
                        .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: AI Submission

    private func submitTask() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true

        Task {
            do {
                let responses = try await AIManager().parseInput(text: text, existingTasks: tasks)

                await MainActor.run {
                    for response in responses {
                        switch response {
                        case .create(let data):
                            let task = LifeTask(
                                title: data.title,
                                startTime: data.startTime,
                                endTime: data.endTime,
                                targetDate: data.targetDate,
                                timeDisplay: data.timeDisplay,
                                location: data.location,
                                notes: data.notes,
                                taskType: data.taskType,
                                isExactTime: data.isExactTime,
                                exactStartTime: data.exactStartTime,
                                exactEndTime: data.exactEndTime
                            )
                            modelContext.insert(task)
                            try? modelContext.save()
                            NotificationManager.shared.scheduleNotification(for: task)

                        case .update(let taskId, let data):
                            if let existing = tasks.first(where: { $0.id == taskId }) {
                                existing.title = data.title
                                existing.startTime = data.startTime
                                existing.endTime = data.endTime
                                existing.targetDate = data.targetDate
                                existing.timeDisplay = data.timeDisplay
                                existing.location = data.location
                                existing.notes = data.notes
                                existing.taskType = data.taskType
                                existing.isExactTime = data.isExactTime
                                existing.exactStartTime = data.exactStartTime
                                existing.exactEndTime = data.exactEndTime
                                try? modelContext.save()
                                NotificationManager.shared.cancelNotification(for: taskId)
                                NotificationManager.shared.scheduleNotification(for: existing)
                            }

                        case .delete(let taskId):
                            if let existing = tasks.first(where: { $0.id == taskId }) {
                                NotificationManager.shared.cancelNotification(for: taskId)
                                modelContext.delete(existing)
                                try? modelContext.save()
                            }

                        case .clarify(let question):
                            clarifyMessage = question
                            showClarifyAlert = true
                        }
                    }
                    inputText = ""
                }
            } catch {
                print("[ContentView] AI PARSE ERROR: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - DrawerMenuView

struct DrawerMenuView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: StudyHubView()) {
                        Label(L10n.study, systemImage: "brain.head.profile")
                    }

                    NavigationLink(destination: HealthView()) {
                        Label(L10n.health, systemImage: "heart.fill")
                    }

                    NavigationLink(destination: FinanceView()) {
                        Label(L10n.finance, systemImage: "chart.pie.fill")
                    }
                }

                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label(L10n.settings, systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle(L10n.modules)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - StudyHubView

struct StudyHubView: View {
    @Query(sort: \LifeTask.startTime) private var allTasks: [LifeTask]
    @Environment(\.modelContext) private var modelContext

    private var studyTasks: [LifeTask] {
        allTasks.filter { $0.taskType == .study }
    }

    var body: some View {
        List {
            if studyTasks.isEmpty {
                ContentUnavailableView(
                    L10n.noStudyTasks,
                    systemImage: "brain.head.profile",
                    description: Text(L10n.createStudyHint)
                )
            } else {
                ForEach(studyTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskCardView(task: task)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(studyTasks[index])
                    }
                }
            }
        }
        .navigationTitle(L10n.study)
        .listStyle(.plain)
    }
}

// MARK: - Keyboard Dismiss Utility

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
