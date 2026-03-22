import AppKit

final class ActivityMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private let eventMask: NSEvent.EventTypeMask = [
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .scrollWheel,
        .keyDown,
        .flagsChanged
    ]

    func start(onActivity: @escaping @MainActor () -> Void) {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { _ in
            Task { @MainActor in
                onActivity()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { event in
            Task { @MainActor in
                onActivity()
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
