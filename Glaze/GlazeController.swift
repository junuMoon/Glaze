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

    private var scheduler: BreakScheduler
    private var ticker: DispatchSourceTimer?

    private enum DefaultsKey {
        static let workMinutes = "Glaze.workMinutes"
        static let breakSeconds = "Glaze.breakSeconds"
        static let headsUpSeconds = "Glaze.headsUpSeconds"
    }

    override init() {
        let loadedSettings = Self.loadSettings()
        settings = loadedSettings
        scheduler = BreakScheduler(settings: loadedSettings)
        snapshot = scheduler.tick()
        super.init()
        configurePopover()
        configureStatusItem()
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
            return "Paused"
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
            return "Hold the rhythm"
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

    func pauseOrResume() {
        switch snapshot.phase {
        case .paused:
            snapshot = scheduler.resume()
        default:
            snapshot = scheduler.pause()
        }
        refreshUI()
    }

    func snoozeOneMinute() {
        snapshot = scheduler.snooze(seconds: 60)
        refreshUI()
    }

    func startBreakNow() {
        snapshot = scheduler.startBreakNow()
        refreshUI()
    }

    func skipBreak() {
        snapshot = scheduler.skipBreak()
        refreshUI()
    }

    func resetCycle() {
        snapshot = scheduler.resetCycle()
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
        popover.contentSize = NSSize(width: 360, height: 520)
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
        snapshot = scheduler.tick()
        refreshUI()
    }

    private func applySettings() {
        settings = settings.sanitized()
        saveSettings(settings)
        snapshot = scheduler.updateSettings(settings)
        refreshUI()
    }

    private func refreshUI() {
        updateStatusItem()
        syncOverlay()
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
            label = "Paused"
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
