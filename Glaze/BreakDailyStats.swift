import Foundation

struct BreakDaySummary: Equatable {
    let breakDuration: TimeInterval
    let elapsedDayDuration: TimeInterval

    var dayFraction: Double {
        guard elapsedDayDuration > 0 else { return 0 }
        return min(max(breakDuration / elapsedDayDuration, 0), 1)
    }
}

struct BreakShareIndicator: Equatable {
    enum Level: Equatable {
        case warning
        case caution
        case healthy
    }

    static let warningThreshold = 0.005
    static let healthyThreshold = 0.01

    let fraction: Double

    init(fraction: Double) {
        self.fraction = min(max(fraction, 0), 1)
    }

    var level: Level {
        if fraction < Self.warningThreshold {
            return .warning
        }

        if fraction < Self.healthyThreshold {
            return .caution
        }

        return .healthy
    }
}

protocol BreakStatsStoring {
    func loadDailyBreakDurations() -> [String: TimeInterval]
    func saveDailyBreakDurations(_ durations: [String: TimeInterval])
}

struct UserDefaultsBreakStatsStore: BreakStatsStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "Glaze.dailyBreakDurations"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadDailyBreakDurations() -> [String: TimeInterval] {
        let storedValues = defaults.dictionary(forKey: key) ?? [:]
        return storedValues.compactMapValues { value in
            if let duration = value as? TimeInterval {
                return duration
            }

            if let number = value as? NSNumber {
                return number.doubleValue
            }

            return nil
        }
    }

    func saveDailyBreakDurations(_ durations: [String: TimeInterval]) {
        defaults.set(durations, forKey: key)
    }
}

final class BreakDailyStatsTracker {
    private let store: any BreakStatsStoring
    private let calendar: Calendar

    private var dailyBreakDurations: [String: TimeInterval]

    init(
        store: any BreakStatsStoring = UserDefaultsBreakStatsStore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        self.calendar = calendar
        dailyBreakDurations = store.loadDailyBreakDurations()
    }

    func recordBreak(from start: Date, to end: Date) {
        guard end > start else { return }

        var segmentStart = start

        while segmentStart < end {
            let dayStart = calendar.startOfDay(for: segmentStart)
            let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let segmentEnd = min(end, nextDayStart)
            let key = dayKey(for: dayStart)
            dailyBreakDurations[key, default: 0] += segmentEnd.timeIntervalSince(segmentStart)
            segmentStart = segmentEnd
        }

        store.saveDailyBreakDurations(dailyBreakDurations)
    }

    func summary(for date: Date) -> BreakDaySummary {
        let dayStart = calendar.startOfDay(for: date)
        let elapsedDayDuration = max(date.timeIntervalSince(dayStart), 1)
        let breakDuration = dailyBreakDurations[dayKey(for: dayStart), default: 0]

        return BreakDaySummary(
            breakDuration: breakDuration,
            elapsedDayDuration: elapsedDayDuration
        )
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
