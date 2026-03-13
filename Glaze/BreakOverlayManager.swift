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
            GlazeOverlayBackdrop()

            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    GlazePill(icon: "sparkles", label: "Glaze Break", accented: true)

                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 104, height: 104)

                            Circle()
                                .fill(GlazeTheme.accentPink.opacity(0.16))
                                .frame(width: 144, height: 144)
                                .blur(radius: 28)

                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 58, weight: .semibold))
                                .foregroundStyle(GlazeTheme.textPrimary)
                        }

                        Text(controller.overlayTitleText)
                            .font(.system(size: 46, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlazeTheme.textPrimary)

                        Text(controller.overlayDetailText)
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(GlazeTheme.textSecondary)
                            .multilineTextAlignment(.center)

                        Text(controller.countdownText)
                            .font(.system(size: 92, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(GlazeTheme.textPrimary)
                    }

                    HStack(spacing: 12) {
                        Button("Skip Break") {
                            controller.skipBreak()
                        }
                        .buttonStyle(GlazeGhostButtonStyle())

                        Button("Pause Timer") {
                            controller.pauseOrResume()
                        }
                        .buttonStyle(GlazeSecondaryButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(GlazeTheme.stroke, lineWidth: 1)
                            )
                    )
                }
                .frame(maxWidth: 560)
                .padding(44)

                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.dark)
    }
}
