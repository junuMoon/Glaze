import Foundation
import IOKit
import IOKit.hidsystem

enum PauseSource: Equatable {
    case manual
    case idle
}

enum IdleAutoPauseAction: Equatable {
    case none
    case pause
    case resume
}

struct IdleAutoPausePolicy: Equatable {
    static let defaultPauseThreshold: TimeInterval = 300
    static let defaultResumeThreshold: TimeInterval = 2

    var pauseThreshold: TimeInterval = Self.defaultPauseThreshold
    var resumeThreshold: TimeInterval = Self.defaultResumeThreshold

    func action(
        for phase: SessionPhase,
        pauseSource: PauseSource?,
        idleSeconds: TimeInterval
    ) -> IdleAutoPauseAction {
        if pauseSource == .manual {
            return .none
        }

        if pauseSource == .idle {
            return idleSeconds <= resumeThreshold ? .resume : .none
        }

        switch phase {
        case .working, .headsUp:
            return idleSeconds >= pauseThreshold ? .pause : .none
        case .breaking, .paused:
            return .none
        }
    }
}

protocol IdleTimeProviding {
    func idleTimeInterval() -> TimeInterval
}

struct SystemIdleTimeProvider: IdleTimeProviding {
    func idleTimeInterval() -> TimeInterval {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(
            service,
            kIOHIDIdleTimeKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return 0
        }

        if let nanoseconds = property as? NSNumber {
            return nanoseconds.doubleValue / 1_000_000_000
        }

        if let data = property as? Data {
            return data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress,
                      rawBuffer.count >= MemoryLayout<UInt64>.size else {
                    return 0
                }

                let nanoseconds = baseAddress.assumingMemoryBound(to: UInt64.self).pointee
                return TimeInterval(nanoseconds) / 1_000_000_000
            }
        }

        return 0
    }
}
