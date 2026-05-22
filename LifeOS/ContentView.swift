import SwiftUI
import SwiftData
import AVFoundation

// MARK: - ContentView

struct ContentView: View {

    @AppStorage("theme") private var theme = "system"
    @AppStorage("language") private var language = "en"
    @State private var selectedTab = 0
    @State private var isVaultDrawerOpen = false

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
                VStack(spacing: 0) {
                    headerBar
                    nativeTabView
                }
                .background(Color(UIColor.systemGroupedBackground))

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
                    .frame(minWidth: 44, minHeight: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Native TabView

    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem {
                    Label(L10n.schedule, systemImage: "calendar.day.timeline.left")
                }
                .tag(0)

            StudyHubView()
                .tabItem {
                    Label(L10n.study, systemImage: "brain.head.profile")
                }
                .tag(1)

            HealthView()
                .tabItem {
                    Label(L10n.health, systemImage: "heart.fill")
                }
                .tag(2)

            FinanceView()
                .tabItem {
                    Label(L10n.finance, systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            VisionView()
                .tabItem {
                    Label(L10n.vision, systemImage: "eye.fill")
                }
                .tag(4)
        }
        .tint(.indigo)
    }
}

// MARK: - DrawerMenuView

struct DrawerMenuView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
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
    @Query(sort: \FocusSession.date, order: .reverse) private var focusSessions: [FocusSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusEngineManager.self) private var engine
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isSetsFocused: Bool
    @FocusState private var isDurationFocused: Bool

    // Local language binding to force segmented control refresh
    @AppStorage("language") private var language = "en"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                focusDashboard
                focusHistorySection
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .overlay {
            if engine.showPrompt, let prompt = engine.currentPrompt {
                promptOverlay(prompt)
            }
        }
        .overlay {
            if engine.showSessionComplete {
                sessionCompleteOverlay
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            engine.tick()
        }
        .onAppear {
            engine.setModelContext(modelContext)
            engine.catchUpElapsedTime()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                engine.didEnterBackground()
            case .active:
                engine.didEnterForeground()
            default:
                break
            }
        }
    }

    // MARK: Focus Dashboard

    private var focusDashboard: some View {
        VStack(spacing: 20) {
            Picker(L10n.methodLabel, selection: Binding(
                get: { engine.studyMethod },
                set: { engine.studyMethod = $0 }
            )) {
                ForEach(FocusEngineManager.FocusMethod.allCases, id: \.self) { method in
                    Text(method == .pomodoro ? L10n.pomodoroMethod : L10n.randomPromptMethod)
                        .tag(method)
                }
            }
            .pickerStyle(.segmented)
            .id(language)

            if engine.studyMethod == .pomodoro {
                pomodoroDashboard
            } else {
                randomPromptPanel
            }

            TextField(L10n.studyContentPlaceholder, text: Binding(
                get: { engine.studyContent },
                set: { engine.studyContent = $0 }
            ), axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .lineLimit(1...4)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Pomodoro Dashboard

    private var pomodoroDashboard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(
                        engine.isBreakActive ? Color.orange.opacity(0.06) : Color.blue.opacity(0.06),
                        lineWidth: 14
                    )
                Circle()
                    .trim(from: 0, to: engine.isBreakActive
                        ? CGFloat(engine.breakSecondsRemaining) / CGFloat(engine.breakDuration)
                        : CGFloat(engine.focusSecondsRemaining) / CGFloat(engine.focusDuration)
                    )
                    .stroke(
                        engine.isBreakActive ? Color.orange : Color.blue,
                        style: SwiftUI.StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: engine.isBreakActive ? engine.breakSecondsRemaining : engine.focusSecondsRemaining)

                VStack(spacing: 2) {
                    Text(timeString(from: engine.isBreakActive ? engine.breakSecondsRemaining : engine.focusSecondsRemaining))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(engine.isBreakActive ? L10n.breakLabel : L10n.focusLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(engine.isBreakActive ? .orange : .blue)
                }
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 5) {
                ForEach(1...engine.numberOfSets, id: \.self) { set in
                    Circle()
                        .fill(engine.setDotColor(for: set))
                        .frame(width: 8, height: 8)
                        .scaleEffect(set == engine.currentSet && (engine.isFocusActive || engine.isBreakActive) ? 1.4 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: engine.currentSet)
                }
            }

            dashboardControls

            HStack(spacing: 20) {
                Button {
                    if engine.isFocusActive || engine.isBreakActive {
                        engine.pauseEngine()
                    } else {
                        engine.startEngine()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: engine.isFocusActive || engine.isBreakActive ? "pause.fill" : "play.fill")
                        Text(engine.isFocusActive || engine.isBreakActive ? L10n.pause : L10n.start)
                    }
                    .fontWeight(.semibold)
                    .font(.body)
                    .frame(minWidth: 120)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.isBreakActive ? .orange : .blue)
                .controlSize(.large)

                Button {
                    engine.resetEngine()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                    Text(L10n.reset)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Dashboard Controls — Sets & Duration

    private var dashboardControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(L10n.setsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Button {
                    if engine.numberOfSets > 1 { engine.updateSets(engine.numberOfSets - 1) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(engine.numberOfSets > 1 && !(engine.isFocusActive || engine.isBreakActive) ? .blue : .gray.opacity(0.3))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(engine.isFocusActive || engine.isBreakActive || engine.numberOfSets <= 1)

                TextField("", text: Binding(
                    get: { engine.numberOfSetsText },
                    set: { engine.numberOfSetsText = $0 }
                ))
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .focused($isSetsFocused)
                    .disabled(engine.isFocusActive || engine.isBreakActive)
                    .onChange(of: isSetsFocused) { _, focused in
                        if !focused { engine.commitSetsText() }
                    }

                Button {
                    if engine.numberOfSets < 32 { engine.updateSets(engine.numberOfSets + 1) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(engine.numberOfSets < 32 && !(engine.isFocusActive || engine.isBreakActive) ? .blue : .gray.opacity(0.3))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(engine.isFocusActive || engine.isBreakActive || engine.numberOfSets >= 32)
            }

            Rectangle()
                .fill(.secondary.opacity(0.15))
                .frame(width: 1, height: 24)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(L10n.learningDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                TextField("", text: Binding(
                    get: { engine.learningMinutesText },
                    set: { engine.learningMinutesText = $0 }
                ))
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .focused($isDurationFocused)
                    .disabled(engine.isFocusActive || engine.isBreakActive)
                    .onChange(of: isDurationFocused) { _, focused in
                        if !focused { engine.commitDurationText() }
                    }

                Text(L10n.minutesUnit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .baselineOffset(0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Random Prompt Panel

    private var randomPromptPanel: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                // Subtle breathing ring indicator instead of bouncing icon
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.indigo, .indigo.opacity(0.4), .indigo.opacity(0.2), .indigo.opacity(0.4)]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(engine.isBeepSessionActive ? 360 : 0))
                        .animation(
                            engine.isBeepSessionActive
                                ? .linear(duration: 4).repeatForever(autoreverses: false)
                                : .default,
                            value: engine.isBeepSessionActive
                        )

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                }

                Text(L10n.randomPromptDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }

            Button {
                if engine.isBeepSessionActive {
                    engine.stopBeepEngine()
                } else {
                    engine.startBeepEngine()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: engine.isBeepSessionActive ? "stop.fill" : "play.fill")
                    Text(engine.isBeepSessionActive ? L10n.endSession : L10n.startSession)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.isBeepSessionActive ? .red : .indigo)
            .controlSize(.regular)

            if engine.isBeepSessionActive {
                Text(L10n.sessionActiveHint)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Focus History

    private var focusHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "clock.arrow.2.circlepath")
                    .foregroundStyle(.blue)
                Text(L10n.focusHistory)
                    .font(.headline)
                Spacer()

                if !focusSessions.isEmpty {
                    Text("\(focusSessions.count) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }

            if focusSessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(L10n.noFocusSessions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(L10n.startFocusHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // Split focus sessions by method
                let pomodoroSessions = focusSessions.filter { $0.method == "pomodoro" }
                let randomSessions = focusSessions.filter { $0.method != "pomodoro" }

                VStack(alignment: .leading, spacing: 16) {
                    if !pomodoroSessions.isEmpty {
                        sessionGroupHeader(
                            icon: "timer",
                            title: L10n.pomodoroMethod,
                            count: pomodoroSessions.count,
                            color: .blue
                        )
                        VStack(spacing: 8) {
                            ForEach(pomodoroSessions.prefix(15)) { session in
                                focusSessionRow(session)
                            }
                        }
                    }

                    if !randomSessions.isEmpty {
                        sessionGroupHeader(
                            icon: "waveform",
                            title: L10n.randomPromptMethod,
                            count: randomSessions.count,
                            color: .indigo
                        )
                        VStack(spacing: 8) {
                            ForEach(randomSessions.prefix(15)) { session in
                                focusSessionRow(session)
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: focusSessions.count)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sessionGroupHeader(icon: String, title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func focusSessionRow(_ session: FocusSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(session.method == "pomodoro" ? Color.blue.opacity(0.1) : Color.indigo.opacity(0.1))
                    .frame(width: 34, height: 34)
                Image(systemName: session.method == "pomodoro" ? "timer" : "waveform")
                    .font(.caption2)
                    .foregroundStyle(session.method == "pomodoro" ? .blue : .indigo)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if session.totalSets > 1 {
                        Text("\(session.setsCompleted)/\(session.totalSets) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let content = session.studyContent, !content.isEmpty {
                    Text(content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(engine.formatDuration(session.durationSeconds))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()

                Text(session.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Prompt Overlay

    private func promptOverlay(_ prompt: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text(prompt)
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    engine.showPrompt = false
                }
            }
        }
    }

    // MARK: Session Complete Overlay

    private var sessionCompleteOverlay: some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(L10n.sessionComplete)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(L10n.greatWork)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
        }
        .transition(.scale.combined(with: .opacity))
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

// MARK: - Helpers

private func timeString(from seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}

// MARK: - Preview

#Preview {
    ContentView()
}
