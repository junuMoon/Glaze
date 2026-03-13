import AppKit
import SwiftUI

@MainActor
final class BreakOverlayManager {
    private var windows: [BreakOverlayWindow] = []

    func show(controller: GlazeController) {
        guard windows.isEmpty else { return }

        windows = NSScreen.screens.map { makeWindow(for: $0, controller: controller) }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen, controller: GlazeController) -> BreakOverlayWindow {
        let window = BreakOverlayWindow(
            contentRect: NSRect(origin: .zero, size: screen.frame.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovable = false
        window.contentView = NSHostingView(rootView: BreakOverlayView(controller: controller))
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        return window
    }
}

final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct BreakOverlayView: View {
    @ObservedObject var controller: GlazeController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.88),
                    Color(red: 0.16, green: 0.08, blue: 0.22).opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.pink.opacity(0.9))

                Text("Look away for a moment")
                    .font(.system(size: 40, weight: .semibold))

                Text(controller.phaseDetailText)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.7))

                Text(controller.countdownText)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 12) {
                    Button("Skip Break") {
                        controller.skipBreak()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Pause Timer") {
                        controller.pauseOrResume()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.large)
                }
            }
            .padding(40)
        }
    }
}
