import AppKit
import Combine
import SwiftUI

@MainActor
final class GlazeController: NSObject, ObservableObject {
    @Published private(set) var snapshot: SessionSnapshot
    @Published private(set) var settings: BreakSettings

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let overlayManager = BreakOverlayManager()
    private let activityMonitor = ActivityMonitor()
    private let idleTimeProvider: any IdleTimeProviding
    private let idleAutoPausePolicy: IdleAutoPausePolicy
    private let meetingMonitor: any MeetingStatusProviding
    private let meetingAutoPausePolicy: MeetingAutoPausePolicy
    private let breakStatsTracker: BreakDailyStatsTracker

    private var scheduler: BreakScheduler
    private var ticker: DispatchSourceTimer?
    private var pauseSource: PauseSource?
    private var lastBreakAccountingDate: Date

    private enum DefaultsKey {
        static let workMinutes = "Glaze.workMinutes"
        static let breakSeconds = "Glaze.breakSeconds"
        static let headsUpSeconds = "Glaze.headsUpSeconds"
    }

    init(
        idleTimeProvider: any IdleTimeProviding = SystemIdleTimeProvider(),
        idleAutoPausePolicy: IdleAutoPausePolicy = IdleAutoPausePolicy(),
        meetingMonitor: any MeetingStatusProviding = MeetingMonitor(),
        meetingAutoPausePolicy: MeetingAutoPausePolicy = MeetingAutoPausePolicy(),
        breakStatsTracker: BreakDailyStatsTracker = BreakDailyStatsTracker()
    ) {
        let now = Date.now
        self.idleTimeProvider = idleTimeProvider
        self.idleAutoPausePolicy = idleAutoPausePolicy
        self.meetingMonitor = meetingMonitor
        self.meetingAutoPausePolicy = meetingAutoPausePolicy
        self.breakStatsTracker = breakStatsTracker
        lastBreakAccountingDate = now
        let loadedSettings = Self.loadSettings()
        settings = loadedSettings
        scheduler = BreakScheduler(settings: loadedSettings, now: now)
        snapshot = scheduler.tick(now: now)
        super.init()
        configurePopover()
        configureStatusItem()
        configureActivityMonitor()
        configureMeetingMonitor()
        startTicker()
        refreshUI()
    }

    var countdownText: String {
        formatDuration(snapshot.remaining)
    }

    var phaseSymbolName: String {
        switch snapshot.phase {
        case .working:
            return "timer"
        case .headsUp:
            return "bell.badge.fill"
        case .breaking:
            return "eye.circle.fill"
        case .paused:
            return "pause.circle.fill"
        }
    }

    var phaseBadgeText: String {
        switch snapshot.phase {
        case .working:
            return "In Focus"
        case .headsUp:
            return "Heads-up"
        case .breaking:
            return "Break Live"
        case .paused:
            if isMeetingPaused {
                return "In Meeting"
            }

            return isIdlePaused ? "Auto-paused" : "Paused"
        }
    }

    var menuHeroTitle: String {
        switch snapshot.phase {
        case .working:
            return "Keep your momentum"
        case .headsUp:
            return "Wrap this thought"
        case .breaking:
            return "Time to reset"
        case .paused:
            if isMeetingPaused {
                return "Time frozen for your meeting"
            }

            return isIdlePaused ? "Paused while you're away" : "Hold the rhythm"
        }
    }

    var menuDetailText: String {
        switch snapshot.phase {
        case .working:
            return "A gentle heads-up will appear before the next break so you can stay in flow."
        case .headsUp:
            return "Take the break now, or snooze it for a minute without losing the thread."
        case .breaking:
            return "Look away, breathe once, and let the next focus block begin on its own."
        case .paused:
            if isMeetingPaused {
                return "The cycle stays paused while a current busy calendar event is underway."
            }

            if isIdlePaused {
                return "The cycle stopped after \(idleThresholdText) of idle time and will resume when you come back."
            }

            return "Nothing is moving right now. Resume whenever you want the cycle back."
        }
    }

    var overlayTitleText: String {
        "Look away for a moment"
    }

    var overlayDetailText: String {
        "Relax your eyes. The next focus block starts automatically."
    }

    var phaseTitleText: String {
        switch snapshot.phase {
        case .working:
            return "Focus block"
        case .headsUp:
            return "Break incoming"
        case .breaking:
            return "Short break"
        case .paused(let resumePhase):
            if isMeetingPaused {
                return "Meeting in progress"
            }

            if isIdlePaused {
                return "Auto-paused while away"
            }

            switch resumePhase {
            case .working:
                return "Focus paused"
            case .headsUp:
                return "Heads-up paused"
            case .breaking:
                return "Break paused"
            }
        }
    }

    var autoPauseSummaryText: String {
        "Auto-pauses during busy calendar events, and after \(idleThresholdText) of idle time during focus or heads-up."
    }

    var todayBreakDurationText: String {
        breakDurationText(for: todayBreakSummary.breakDuration)
    }

    var todayBreakShareText: String {
        String(format: "%.1f%%", todayBreakShareIndicator.fraction * 100)
    }

    var todayBreakShareIndicator: BreakShareIndicator {
        BreakShareIndicator(fraction: todayBreakSummary.dayFraction)
    }

    var todayBreakDetailText: String {
        if snapshot.phase == .breaking {
            return "Counting while you stay on break."
        }

        return "Tracked across breaks you actually kept today."
    }

    var pausedPrimaryActionTitle: String {
        if isMeetingPaused {
            return "Meeting Active"
        }

        return isIdlePaused ? "Resume Now" : "Resume"
    }

    var isMeetingPauseActive: Bool {
        isMeetingPaused
    }

    func pauseOrResume() {
        let now = Date.now
        recordBreakTime(until: now)

        if isMeetingPaused, meetingMonitor.isMeetingInProgress(at: now) {
            refreshUI()
            return
        }

        switch snapshot.phase {
        case .paused:
            snapshot = scheduler.resume(now: now)
            pauseSource = nil
        default:
            snapshot = scheduler.pause(now: now)
            pauseSource = .manual
        }
        refreshUI()
    }

    func snoozeOneMinute() {
        let now = Date.now
        recordBreakTime(until: now)
        snapshot = scheduler.snooze(seconds: 60, now: now)
        refreshUI()
    }

    func startBreakNow() {
        let now = Date.now
        recordBreakTime(until: now)
        snapshot = scheduler.startBreakNow(now: now)
        pauseSource = nil
        refreshUI()
    }

    func skipBreak() {
        let now = Date.now
        recordBreakTime(until: now)
        snapshot = scheduler.skipBreak(now: now)
        pauseSource = nil
        refreshUI()
    }

    func resetCycle() {
        let now = Date.now
        recordBreakTime(until: now)
        snapshot = scheduler.resetCycle(now: now)
        pauseSource = nil
        refreshUI()
    }

    func updateWorkMinutes(_ minutes: Int) {
        settings.workMinutes = minutes
        applySettings()
    }

    func updateBreakSeconds(_ seconds: Int) {
        settings.breakSeconds = seconds
        applySettings()
    }

    func updateHeadsUpSeconds(_ seconds: Int) {
        settings.headsUpSeconds = seconds
        applySettings()
    }

    func quit() {
        recordBreakTime(until: Date.now)
        NSApp.terminate(nil)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 360, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(controller: self)
                .environment(\.colorScheme, .dark)
        )
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        button.imagePosition = .imageLeft
    }

    private func configureActivityMonitor() {
        activityMonitor.start { [weak self] in
            self?.handleObservedActivity()
        }
    }

    private func configureMeetingMonitor() {
        meetingMonitor.start()
    }

    private func startTicker() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleTick()
            }
        }
        ticker = timer
        timer.resume()
    }

    private func handleTick() {
        let now = Date.now
        recordBreakTime(until: now)
        evaluateMeetingAutoPause(now: now)
        evaluateIdleAutoPause(now: now)
        snapshot = scheduler.tick(now: now)
        refreshUI()
    }

    private func applySettings() {
        let now = Date.now
        recordBreakTime(until: now)
        settings = settings.sanitized()
        saveSettings(settings)
        snapshot = scheduler.updateSettings(settings, now: now)
        refreshUI()
    }

    private func refreshUI() {
        normalizePauseSource()
        updateStatusItem()
        syncOverlay()
    }

    private func evaluateMeetingAutoPause(now: Date) {
        let isMeetingActive = meetingMonitor.isMeetingInProgress(at: now)
        let action = meetingAutoPausePolicy.action(
            for: snapshot.phase,
            pauseSource: pauseSource,
            isMeetingActive: isMeetingActive
        )

        switch action {
        case .pause:
            snapshot = scheduler.pause(now: now)
            pauseSource = .meeting
        case .adoptMeetingPause:
            pauseSource = .meeting
        case .resume:
            snapshot = scheduler.resume(now: now)
            pauseSource = nil
        case .none:
            break
        }
    }

    private func evaluateIdleAutoPause(now: Date) {
        let idleSeconds = idleTimeProvider.idleTimeInterval()
        let action = idleAutoPausePolicy.action(
            for: snapshot.phase,
            pauseSource: pauseSource,
            idleSeconds: idleSeconds
        )

        switch action {
        case .pause:
            snapshot = scheduler.pause(now: now)
            pauseSource = .idle
        case .resume:
            snapshot = scheduler.resume(now: now)
            pauseSource = nil
        case .none:
            break
        }
    }

    private func handleObservedActivity() {
        guard pauseSource == .idle else { return }
        guard case .paused = snapshot.phase else { return }

        let now = Date.now
        snapshot = scheduler.resume(now: now)
        pauseSource = nil
        refreshUI()
    }

    private func recordBreakTime(until now: Date) {
        guard now > lastBreakAccountingDate else { return }

        if snapshot.phase == .breaking {
            breakStatsTracker.recordBreak(from: lastBreakAccountingDate, to: now)
        }

        lastBreakAccountingDate = now
    }

    private func normalizePauseSource() {
        guard case .paused = snapshot.phase else {
            pauseSource = nil
            return
        }
    }

    private func syncOverlay() {
        switch snapshot.phase {
        case .breaking:
            if popover.isShown {
                popover.performClose(nil)
            }
            overlayManager.show(controller: self)
        default:
            overlayManager.hide()
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let label: String

        switch snapshot.phase {
        case .working:
            label = shortLabel(for: snapshot.remaining, style: .minutes)
        case .headsUp:
            label = shortLabel(for: snapshot.remaining, style: .seconds)
        case .breaking:
            label = shortLabel(for: snapshot.remaining, style: .seconds)
        case .paused:
            if isMeetingPaused {
                label = "Meeting"
            } else {
                label = isIdlePaused ? "Away" : "Paused"
            }
        }

        button.image = symbolImage(named: phaseSymbolName)
        button.attributedTitle = NSAttributedString(
            string: " \(label)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )
        button.toolTip = "\(phaseTitleText) • \(countdownText)"
    }

    private func shortLabel(for seconds: TimeInterval, style: ShortLabelStyle) -> String {
        let clamped = max(0, Int(seconds.rounded()))
        switch style {
        case .minutes:
            let minutes = max(1, Int(ceil(Double(clamped) / 60.0)))
            return "\(minutes)m"
        case .seconds:
            return "\(clamped)s"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var isIdlePaused: Bool {
        pauseSource == .idle
    }

    private var isMeetingPaused: Bool {
        pauseSource == .meeting
    }

    private var idleThresholdText: String {
        naturalDurationText(for: idleAutoPausePolicy.pauseThreshold)
    }

    private func naturalDurationText(for duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))

        if total >= 60, total % 60 == 0 {
            return "\(total / 60) min"
        }

        if total >= 60 {
            return "\(total / 60)m \(total % 60)s"
        }

        return "\(total) sec"
    }

    private func breakDurationText(for duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var todayBreakSummary: BreakDaySummary {
        breakStatsTracker.summary(for: Date.now)
    }

    private func symbolImage(named name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        return image?.withSymbolConfiguration(config)
    }

    private static func loadSettings() -> BreakSettings {
        let defaults = UserDefaults.standard

        let workMinutes = defaults.object(forKey: DefaultsKey.workMinutes) as? Int
            ?? BreakSettings.default.workMinutes
        let breakSeconds = defaults.object(forKey: DefaultsKey.breakSeconds) as? Int
            ?? BreakSettings.default.breakSeconds
        let headsUpSeconds = defaults.object(forKey: DefaultsKey.headsUpSeconds) as? Int
            ?? BreakSettings.default.headsUpSeconds

        let storedSettings = BreakSettings(
            workMinutes: workMinutes,
            breakSeconds: breakSeconds,
            headsUpSeconds: headsUpSeconds
        )

        let sanitizedSettings = BreakSettings(
            workMinutes: workMinutes,
            breakSeconds: breakSeconds,
            headsUpSeconds: headsUpSeconds
        ).sanitized()

        if sanitizedSettings != storedSettings {
            defaults.set(sanitizedSettings.workMinutes, forKey: DefaultsKey.workMinutes)
            defaults.set(sanitizedSettings.breakSeconds, forKey: DefaultsKey.breakSeconds)
            defaults.set(sanitizedSettings.headsUpSeconds, forKey: DefaultsKey.headsUpSeconds)
        }

        return sanitizedSettings
    }

    private func saveSettings(_ settings: BreakSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.workMinutes, forKey: DefaultsKey.workMinutes)
        defaults.set(settings.breakSeconds, forKey: DefaultsKey.breakSeconds)
        defaults.set(settings.headsUpSeconds, forKey: DefaultsKey.headsUpSeconds)
    }
}

private enum ShortLabelStyle {
    case minutes
    case seconds
}
