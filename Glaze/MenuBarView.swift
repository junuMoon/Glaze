import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: GlazeController

    var body: some View {
        ZStack {
            GlazePanelBackdrop()

            VStack(spacing: 16) {
                heroSection
                settingsSection
                footerSection
            }
            .padding(18)
        }
        .frame(width: 360)
        .preferredColorScheme(.dark)
    }

    private var heroSection: some View {
        GlazeCardSurface(fill: GlazeTheme.elevatedGradient, padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 38, height: 38)

                            Image(systemName: controller.phaseSymbolName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(GlazeTheme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Glaze")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(GlazeTheme.textPrimary)

                            Text("A calm break rhythm for your Mac")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(GlazeTheme.textMuted)
                        }
                    }

                    Spacer()

                    GlazePill(
                        icon: controller.phaseSymbolName,
                        label: controller.phaseBadgeText,
                        accented: true
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(controller.menuHeroTitle)
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlazeTheme.textPrimary)

                    Text(controller.countdownText)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GlazeTheme.textPrimary)

                    Text(controller.menuDetailText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(GlazeTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    summaryChip(title: "Focus", value: "\(controller.settings.workMinutes)m")
                    summaryChip(title: "Break", value: "\(controller.settings.breakSeconds)s")
                    summaryChip(title: "Heads-up", value: "\(controller.settings.headsUpSeconds)s")
                }

                Rectangle()
                    .fill(GlazeTheme.stroke)
                    .frame(height: 1)

                actionSection
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        switch controller.snapshot.phase {
        case .working:
            HStack(spacing: 10) {
                Button("Pause") {
                    controller.pauseOrResume()
                }
                .buttonStyle(GlazeSecondaryButtonStyle())

                Button("Start Break Now") {
                    controller.startBreakNow()
                }
                .buttonStyle(GlazePrimaryButtonStyle())
            }
        case .headsUp:
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button("Snooze 1m") {
                        controller.snoozeOneMinute()
                    }
                    .buttonStyle(GlazeSecondaryButtonStyle())

                    Button("Start Break") {
                        controller.startBreakNow()
                    }
                    .buttonStyle(GlazePrimaryButtonStyle())
                }

                Button("Skip This Break") {
                    controller.skipBreak()
                }
                .buttonStyle(GlazeGhostButtonStyle())
            }
        case .breaking:
            HStack(spacing: 10) {
                Button("Pause Timer") {
                    controller.pauseOrResume()
                }
                .buttonStyle(GlazeSecondaryButtonStyle())

                Button("Skip Break") {
                    controller.skipBreak()
                }
                .buttonStyle(GlazeGhostButtonStyle())
            }
        case .paused:
            HStack(spacing: 10) {
                Button("Resume") {
                    controller.pauseOrResume()
                }
                .buttonStyle(GlazePrimaryButtonStyle())

                Button("Reset Cycle") {
                    controller.resetCycle()
                }
                .buttonStyle(GlazeSecondaryButtonStyle())
            }
        }
    }

    private var settingsSection: some View {
        GlazeCardSurface(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Cycle Settings")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlazeTheme.textPrimary)

                    Spacer()

                    Text("Saved locally")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GlazeTheme.textMuted)
                }

                VStack(spacing: 10) {
                    settingStepper(
                        title: "Focus",
                        valueText: "\(controller.settings.workMinutes) min",
                        binding: Binding(
                            get: { controller.settings.workMinutes },
                            set: { controller.updateWorkMinutes($0) }
                        ),
                        range: BreakSettings.workMinutesRange,
                        step: 1
                    )

                    settingStepper(
                        title: "Break",
                        valueText: "\(controller.settings.breakSeconds) sec",
                        binding: Binding(
                            get: { controller.settings.breakSeconds },
                            set: { controller.updateBreakSeconds($0) }
                        ),
                        range: BreakSettings.breakSecondsRange,
                        step: 5
                    )

                    settingStepper(
                        title: "Heads-up",
                        valueText: "\(controller.settings.headsUpSeconds) sec",
                        binding: Binding(
                            get: { controller.settings.headsUpSeconds },
                            set: { controller.updateHeadsUpSeconds($0) }
                        ),
                        range: BreakSettings.headsUpSecondsRange,
                        step: 5
                    )
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Reset Cycle") {
                controller.resetCycle()
            }
            .buttonStyle(GlazeGhostButtonStyle())

            Spacer()

            Button("Quit") {
                controller.quit()
            }
            .buttonStyle(GlazeGhostButtonStyle())
        }
    }

    private func summaryChip(title: String, value: String) -> some View {
        GlazePill(icon: nil, label: "\(title) \(value)")
    }

    private func settingStepper(
        title: String,
        valueText: String,
        binding: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        Stepper(value: binding, in: range, step: step) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlazeTheme.textPrimary)

                Spacer()

                Text(valueText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(GlazeTheme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GlazeTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GlazeTheme.stroke, lineWidth: 1)
                )
        )
    }
}
