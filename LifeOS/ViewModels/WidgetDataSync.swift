import Foundation
import SwiftUI
import Observation
import UserNotifications
import AVFoundation
import SwiftData

// MARK: - WidgetDataSync

/// Writes current focus session state to shared UserDefaults so the Widget can read it.
enum WidgetDataSync {

    private static let suiteName = "group.com.lifeos.app"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func update(
        isActive: Bool,
        isBreak: Bool,
        setsTotal: Int,
        setsCurrent: Int,
        secondsRemaining: Int,
        method: String,
        studyContent: String?
    ) {
        let defaults = sharedDefaults
        defaults.set(isActive, forKey: "widget_focus_active")
        defaults.set(isBreak, forKey: "widget_is_break")
        defaults.set(setsTotal, forKey: "widget_sets_total")
        defaults.set(setsCurrent, forKey: "widget_sets_current")
        defaults.set(secondsRemaining, forKey: "widget_seconds_remaining")
        defaults.set(method, forKey: "widget_method")
        defaults.set(studyContent, forKey: "widget_study_content")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget_last_update")
    }

    static func clear() {
        let defaults = sharedDefaults
        defaults.set(false, forKey: "widget_focus_active")
        defaults.set(false, forKey: "widget_is_break")
        defaults.set(1, forKey: "widget_sets_total")
        defaults.set(1, forKey: "widget_sets_current")
        defaults.set(1500, forKey: "widget_seconds_remaining")
        defaults.set("pomodoro", forKey: "widget_method")
        defaults.set(nil as String?, forKey: "widget_study_content")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget_last_update")
    }
}

// MARK: - FocusEngineManager

@Observable
final class FocusEngineManager {

    // MARK: - Pomodoro State
    var studyMethod: FocusMethod = .pomodoro
    var numberOfSets: Int = 2
    var learningMinutes: Int = 60
    var currentSet: Int = 1
    var isFocusActive = false
    var isBreakActive = false
    var focusSecondsRemaining: Int = 1500
    var breakSecondsRemaining: Int = 300
    var studyContent: String = ""
    var sessionElapsedSeconds: Int = 0
    var sessionStartDate: Date?

    // Text field state
    var numberOfSetsText: String = "2"
    var learningMinutesText: String = "60"

    // MARK: - Random Prompt State
    var beepTargetSeconds: Int = 0
    var beepElapsed: Int = 0
    var isBeepSessionActive = false
    var currentPrompt: String?
    var showPrompt = false

    // MARK: - UI State
    var showSessionComplete = false
    var widgetSyncTick: Int = 0

    // MARK: - Constants
    let focusDuration: Int = 1500
    let breakDuration: Int = 300

    // MARK: - Background & Tab-Switch Tracking
    private var backgroundDate: Date?
    private var backgroundRemainingSeconds: Int = 0
    private var backgroundIsFocus: Bool = true
    private var backgroundIsBreak: Bool = false
    private var backgroundIsBeep: Bool = false

    /// Tracks the last time `tick()` was called, so we can catch up elapsed
    /// time when the view reappears after a tab switch (onReceive stops off-screen).
    private var lastTickTimestamp: Date?

    // MARK: - Dependencies
    private weak var modelContext: ModelContext?

    // MARK: - Prompts
    let learningPrompts = [
        "Take a deep breath. What's the one key insight so far?",
        "Explain what you just learned to an imaginary student.",
        "What question would you ask to test your understanding?",
        "Connect this to something you already know.",
        "If you had to teach this in 60 seconds, what would you say?",
        "What's the most surprising thing you've learned?",
        "How would you apply this knowledge tomorrow?",
        "Pause. What gap in your understanding needs filling?"
    ]

    enum FocusMethod: String, CaseIterable {
        case pomodoro = "Pomodoro"
        case randomPrompt = "Random Prompt"
    }

    // MARK: - Context Injection

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Scene Phase Handling

    func didEnterBackground() {
        guard isFocusActive || isBreakActive || isBeepSessionActive else { return }
        backgroundDate = Date()
        backgroundIsFocus = isFocusActive
        backgroundIsBreak = isBreakActive
        backgroundIsBeep = isBeepSessionActive
        backgroundRemainingSeconds = isBreakActive ? breakSecondsRemaining : focusSecondsRemaining
        scheduleCompletionNotification()
    }

    func didEnterForeground() {
        guard let savedDate = backgroundDate else { return }
        backgroundDate = nil

        let elapsed = Int(Date().timeIntervalSince(savedDate))
        guard elapsed > 0 else { return }

        if backgroundIsBeep {
            beepElapsed += elapsed
            sessionElapsedSeconds += elapsed
            if beepElapsed >= beepTargetSeconds {
                triggerPrompt()
                beepElapsed = 0
                beepTargetSeconds = Int.random(in: 60...300)
            }
            cancelCompletionNotification()
            return
        }

        let newRemaining = backgroundRemainingSeconds - elapsed

        if newRemaining <= 0 {
            if backgroundIsBreak {
                breakSecondsRemaining = 0
                isBreakActive = false
                breakComplete()
            } else if backgroundIsFocus {
                focusSecondsRemaining = 0
                isFocusActive = false
                focusSetComplete()
            }
        } else {
            if backgroundIsFocus {
                focusSecondsRemaining = newRemaining
                isFocusActive = true
                isBreakActive = false
            } else if backgroundIsBreak {
                breakSecondsRemaining = newRemaining
                isBreakActive = true
                isFocusActive = false
            }
            sessionElapsedSeconds += elapsed
            scheduleCompletionNotification()
        }
    }

    /// Catches up elapsed time when the view reappears after a tab switch.
    /// Unlike `didEnterForeground`, this doesn't deal with notification scheduling
    /// because the app never left the foreground — the timer just stopped ticking.
    func catchUpElapsedTime() {
        guard isFocusActive || isBreakActive || isBeepSessionActive else { return }
        guard let lastTick = lastTickTimestamp else { return }

        let elapsed = Int(Date().timeIntervalSince(lastTick))
        guard elapsed > 0 else { return }

        if isBeepSessionActive {
            beepElapsed += elapsed
            sessionElapsedSeconds += elapsed
            if beepElapsed >= beepTargetSeconds {
                triggerPrompt()
                beepElapsed = 0
                beepTargetSeconds = Int.random(in: 60...300)
            }
            return
        }

        if isBreakActive {
            let newRemaining = breakSecondsRemaining - elapsed
            if newRemaining <= 0 {
                breakSecondsRemaining = 0
                isBreakActive = false
                breakComplete()
            } else {
                breakSecondsRemaining = newRemaining
                sessionElapsedSeconds += elapsed
            }
        } else if isFocusActive {
            let newRemaining = focusSecondsRemaining - elapsed
            if newRemaining <= 0 {
                focusSecondsRemaining = 0
                isFocusActive = false
                focusSetComplete()
            } else {
                focusSecondsRemaining = newRemaining
                sessionElapsedSeconds += elapsed
            }
        }
    }

    // MARK: - Timer Tick

    func tick() {
        lastTickTimestamp = Date()
        if isFocusActive && focusSecondsRemaining > 0 {
            focusSecondsRemaining -= 1
            sessionElapsedSeconds += 1
            if focusSecondsRemaining == 0 {
                isFocusActive = false
                cancelCompletionNotification()
                focusSetComplete()
            }
        }
        if isBreakActive && breakSecondsRemaining > 0 {
            breakSecondsRemaining -= 1
            if breakSecondsRemaining == 0 {
                isBreakActive = false
                cancelCompletionNotification()
                breakComplete()
            }
        }
        if isBeepSessionActive {
            beepElapsed += 1
            sessionElapsedSeconds += 1
            if beepElapsed >= beepTargetSeconds {
                triggerPrompt()
                beepElapsed = 0
                beepTargetSeconds = Int.random(in: 60...300)
            }
        }

        widgetSyncTick += 1
        if widgetSyncTick >= 5 {
            widgetSyncTick = 0
            syncWidget()
        }
    }

    // MARK: - Pomodoro Lifecycle

    private func focusSetComplete() {
        AudioServicesPlaySystemSound(1026)
        if currentSet < numberOfSets {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                currentPrompt = learningPrompts.randomElement()
                showPrompt = true
            }
            isBreakActive = true
            breakSecondsRemaining = breakDuration
            scheduleCompletionNotification()
        } else {
            completeSession()
        }
    }

    private func breakComplete() {
        AudioServicesPlaySystemSound(1027)
        showPrompt = false
        currentSet += 1
        focusSecondsRemaining = focusDuration
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFocusActive = true
        }
        scheduleCompletionNotification()
    }

    private func triggerPrompt() {
        AudioServicesPlaySystemSound(1304)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentPrompt = learningPrompts.randomElement()
            showPrompt = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if self.showPrompt { self.showPrompt = false }
            }
        }
    }

    private func completeSession() {
        isFocusActive = false
        isBreakActive = false

        guard let ctx = modelContext else { return }
        let session = FocusSession(
            date: sessionStartDate ?? Date.now,
            durationSeconds: sessionElapsedSeconds,
            method: studyMethod == .pomodoro ? "pomodoro" : "randomPrompt",
            setsCompleted: currentSet,
            totalSets: numberOfSets,
            studyContent: studyContent.isEmpty ? nil : studyContent
        )
        ctx.insert(session)
        try? ctx.save()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showSessionComplete = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.showSessionComplete = false
            }
        }
    }

    // MARK: - Engine Controls

    func startEngine() {
        sessionStartDate = Date.now
        sessionElapsedSeconds = 0
        focusSecondsRemaining = focusDuration
        currentSet = 1
        widgetSyncTick = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFocusActive = true
        }
        syncWidget()
        scheduleCompletionNotification()
    }

    func pauseEngine() {
        isFocusActive = false
        isBreakActive = false
        cancelCompletionNotification()
        syncWidget()
    }

    func resetEngine() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFocusActive = false
            isBreakActive = false
        }
        focusSecondsRemaining = focusDuration
        breakSecondsRemaining = breakDuration
        currentSet = 1
        sessionElapsedSeconds = 0
        sessionStartDate = nil
        cancelCompletionNotification()
        WidgetDataSync.clear()
    }

    func startBeepEngine() {
        sessionStartDate = Date.now
        sessionElapsedSeconds = 0
        isBeepSessionActive = true
        beepElapsed = 0
        beepTargetSeconds = Int.random(in: 60...300)
        widgetSyncTick = 0
        syncWidget()
    }

    func stopBeepEngine() {
        isBeepSessionActive = false
        beepElapsed = 0
        beepTargetSeconds = 0
        completeSession()
    }

    func stopAllTimers() {
        isFocusActive = false
        isBreakActive = false
        isBeepSessionActive = false
        showPrompt = false
        cancelCompletionNotification()
        WidgetDataSync.clear()
    }

    // MARK: - Sets / Duration Helpers

    func updateSets(_ newValue: Int) {
        let clamped = min(max(newValue, 1), 32)
        numberOfSets = clamped
        numberOfSetsText = String(clamped)
        learningMinutes = clamped * 30
        learningMinutesText = String(learningMinutes)
    }

    func commitSetsText() {
        guard let parsed = Int(numberOfSetsText.trimmingCharacters(in: .whitespaces)) else {
            numberOfSetsText = String(numberOfSets)
            return
        }
        updateSets(parsed)
    }

    func commitDurationText() {
        guard let parsed = Int(learningMinutesText.trimmingCharacters(in: .whitespaces)) else {
            learningMinutesText = String(learningMinutes)
            return
        }
        let clamped = min(max(parsed, 30), 960)
        learningMinutes = clamped
        learningMinutesText = String(clamped)
        numberOfSets = Int(ceil(Double(clamped) / 30.0))
        numberOfSetsText = String(numberOfSets)
    }

    func setDotColor(for set: Int) -> Color {
        if set < currentSet { return .green }
        if set == currentSet {
            if isBreakActive { return .orange }
            if isFocusActive { return .blue }
            return .blue.opacity(0.3)
        }
        return .gray.opacity(0.2)
    }

    // MARK: - Widget Sync

    func syncWidget() {
        let seconds = isBreakActive ? breakSecondsRemaining : focusSecondsRemaining
        WidgetDataSync.update(
            isActive: isFocusActive || isBreakActive || isBeepSessionActive,
            isBreak: isBreakActive,
            setsTotal: numberOfSets,
            setsCurrent: currentSet,
            secondsRemaining: seconds,
            method: studyMethod == .pomodoro ? "pomodoro" : "randomPrompt",
            studyContent: studyContent.isEmpty ? nil : studyContent
        )
    }

    // MARK: - Notifications

    private func scheduleCompletionNotification() {
        let remainingSeconds: Int
        if isBreakActive {
            remainingSeconds = breakSecondsRemaining
        } else if isFocusActive {
            remainingSeconds = focusSecondsRemaining + (numberOfSets - currentSet) * (focusDuration + breakDuration)
        } else {
            return
        }

        guard remainingSeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Life OS"
        if isBreakActive {
            content.body = "Break finished — time to focus!"
        } else {
            content.body = "Focus session complete! Great work."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "focus-engine-completion",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[FocusEngineManager] Notification error: \(error.localizedDescription)")
            }
        }
    }

    private func cancelCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["focus-engine-completion"]
        )
    }

    // MARK: - History Formatting

    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m \(seconds % 60)s"
    }
}
