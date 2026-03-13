import Foundation

struct BreakSettings: Equatable {
    static let workMinutesRange = 5...90
    static let breakSecondsRange = 10...300
    static let headsUpSecondsRange = 0...120

    var workMinutes: Int
    var breakSeconds: Int
    var headsUpSeconds: Int

    static let `default` = BreakSettings(
        workMinutes: 20,
        breakSeconds: 20,
        headsUpSeconds: 20
    )

    var workDuration: TimeInterval {
        TimeInterval(workMinutes * 60)
    }

    var breakDuration: TimeInterval {
        TimeInterval(breakSeconds)
    }

    var clampedHeadsUpDuration: TimeInterval {
        min(TimeInterval(headsUpSeconds), max(0, workDuration - 1))
    }

    func sanitized() -> BreakSettings {
        BreakSettings(
            workMinutes: Self.workMinutesRange.clamp(workMinutes),
            breakSeconds: Self.breakSecondsRange.clamp(breakSeconds),
            headsUpSeconds: Self.headsUpSecondsRange.clamp(headsUpSeconds)
        )
    }
}

enum SessionPhase: Equatable {
    case working
    case headsUp
    case breaking
    case paused(resumePhase: ActiveSessionPhase)
}

enum ActiveSessionPhase: Equatable {
    case working
    case headsUp
    case breaking
}

struct SessionSnapshot: Equatable {
    var phase: SessionPhase
    var remaining: TimeInterval
    var total: TimeInterval
    var cycleCount: Int
}

final class BreakScheduler {
    private(set) var settings: BreakSettings

    private var activePhase: ActiveSessionPhase = .working
    private var pausedPhase: ActiveSessionPhase?
    private var pausedRemaining: TimeInterval = 0
    private var phaseStart: Date
    private var phaseEnd: Date
    private var cycleCount: Int = 1

    init(settings: BreakSettings, now: Date = .now) {
        self.settings = settings.sanitized()
        phaseStart = now
        phaseEnd = now.addingTimeInterval(self.settings.workDuration)
    }

    func tick(now: Date = .now) -> SessionSnapshot {
        advanceIfNeeded(now: now)
        return snapshot(now: now)
    }

    func pause(now: Date = .now) -> SessionSnapshot {
        guard pausedPhase == nil else { return snapshot(now: now) }
        pausedPhase = activePhase
        pausedRemaining = max(1, phaseEnd.timeIntervalSince(now))
        return snapshot(now: now)
    }

    func resume(now: Date = .now) -> SessionSnapshot {
        guard let pausedPhase else { return snapshot(now: now) }
        self.pausedPhase = nil
        activePhase = pausedPhase
        phaseStart = now
        phaseEnd = now.addingTimeInterval(pausedRemaining)
        return snapshot(now: now)
    }

    func startBreakNow(now: Date = .now) -> SessionSnapshot {
        startBreak(now: now)
        return snapshot(now: now)
    }

    func snooze(seconds: TimeInterval, now: Date = .now) -> SessionSnapshot {
        guard pausedPhase == nil else { return snapshot(now: now) }
        guard activePhase == .headsUp || activePhase == .working else { return snapshot(now: now) }
        phaseEnd = phaseEnd.addingTimeInterval(seconds)
        activePhase = .working
        phaseStart = now
        return snapshot(now: now)
    }

    func skipBreak(now: Date = .now) -> SessionSnapshot {
        startWorkCycle(now: now)
        return snapshot(now: now)
    }

    func resetCycle(now: Date = .now) -> SessionSnapshot {
        pausedPhase = nil
        startWorkCycle(now: now)
        return snapshot(now: now)
    }

    func updateSettings(_ newSettings: BreakSettings, now: Date = .now) -> SessionSnapshot {
        settings = newSettings.sanitized()

        if let pausedPhase {
            self.pausedPhase = pausedPhase
            pausedRemaining = max(1, pausedRemaining)
            return snapshot(now: now)
        }

        switch activePhase {
        case .working:
            phaseStart = now
            phaseEnd = now.addingTimeInterval(settings.workDuration)
        case .headsUp:
            activePhase = .working
            phaseStart = now
            phaseEnd = now.addingTimeInterval(settings.workDuration)
        case .breaking:
            phaseStart = now
            phaseEnd = now.addingTimeInterval(settings.breakDuration)
        }

        advanceIfNeeded(now: now)
        return snapshot(now: now)
    }

    private func advanceIfNeeded(now: Date) {
        guard pausedPhase == nil else { return }

        while true {
            switch activePhase {
            case .working:
                if now >= phaseEnd {
                    startBreak(now: now)
                    continue
                }

                let headsUp = settings.clampedHeadsUpDuration
                if headsUp > 0, phaseEnd.timeIntervalSince(now) <= headsUp {
                    activePhase = .headsUp
                    phaseStart = phaseEnd.addingTimeInterval(-headsUp)
                    continue
                }
            case .headsUp:
                if now >= phaseEnd {
                    startBreak(now: now)
                    continue
                }
            case .breaking:
                if now >= phaseEnd {
                    startWorkCycle(now: now)
                    continue
                }
            }

            break
        }
    }

    private func startWorkCycle(now: Date) {
        activePhase = .working
        phaseStart = now
        phaseEnd = now.addingTimeInterval(settings.workDuration)
        cycleCount += 1
    }

    private func startBreak(now: Date) {
        activePhase = .breaking
        phaseStart = now
        phaseEnd = now.addingTimeInterval(settings.breakDuration)
    }

    private func remainingForCurrentPhase(now: Date) -> TimeInterval {
        max(1, phaseEnd.timeIntervalSince(now))
    }

    private func totalForCurrentPhase() -> TimeInterval {
        switch activePhase {
        case .working:
            return settings.workDuration
        case .headsUp:
            return max(1, settings.clampedHeadsUpDuration)
        case .breaking:
            return settings.breakDuration
        }
    }

    private func snapshot(now: Date) -> SessionSnapshot {
        if let pausedPhase {
            return SessionSnapshot(
                phase: .paused(resumePhase: pausedPhase),
                remaining: pausedRemaining,
                total: max(pausedRemaining, 1),
                cycleCount: cycleCount
            )
        }

        return SessionSnapshot(
            phase: phase(for: activePhase),
            remaining: max(0, phaseEnd.timeIntervalSince(now)),
            total: max(1, totalForCurrentPhase()),
            cycleCount: cycleCount
        )
    }

    private func phase(for activePhase: ActiveSessionPhase) -> SessionPhase {
        switch activePhase {
        case .working:
            return .working
        case .headsUp:
            return .headsUp
        case .breaking:
            return .breaking
        }
    }
}

private extension ClosedRange where Bound == Int {
    func clamp(_ value: Int) -> Int {
        min(max(value, lowerBound), upperBound)
    }
}
