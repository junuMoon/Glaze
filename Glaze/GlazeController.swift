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

    var phaseTitleText: String {
        switch snapshot.phase {
        case .working:
            return "Focus session"
        case .headsUp:
            return "Break coming up"
        case .breaking:
            return "Break time"
        case .paused(let resumePhase):
            switch resumePhase {
            case .working:
                return "Paused during focus"
            case .headsUp:
                return "Paused before break"
            case .breaking:
                return "Paused during break"
            }
        }
    }

    var phaseDetailText: String {
        switch snapshot.phase {
        case .working:
            return "Stay focused. Glaze will warn you before the break starts."
        case .headsUp:
            return "Wrap up the current thought or snooze the next break."
        case .breaking:
            return "Rest your eyes and let the next work cycle start automatically."
        case .paused:
            return "The timer is paused. Resume when you are ready."
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
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(controller: self))
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

        let symbolName: String
        let label: String

        switch snapshot.phase {
        case .working:
            symbolName = "timer"
            label = shortLabel(for: snapshot.remaining, style: .minutes)
        case .headsUp:
            symbolName = "bell.badge.fill"
            label = shortLabel(for: snapshot.remaining, style: .seconds)
        case .breaking:
            symbolName = "eye.circle.fill"
            label = shortLabel(for: snapshot.remaining, style: .seconds)
        case .paused:
            symbolName = "pause.circle.fill"
            label = "Paused"
        }

        button.image = symbolImage(named: symbolName)
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

        return BreakSettings(
            workMinutes: workMinutes,
            breakSeconds: breakSeconds,
            headsUpSeconds: headsUpSeconds
        )
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
