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
                Button(controller.pausedPrimaryActionTitle) {
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
                    Text("Today & Settings")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlazeTheme.textPrimary)

                    Spacer()

                    Text("Saved locally")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GlazeTheme.textMuted)
                }

                HStack(spacing: 10) {
                    statsTile(
                        title: "Today on break",
                        value: controller.todayBreakDurationText,
                        detail: controller.todayBreakDetailText
                    )

                    shareStatsTile(
                        indicator: controller.todayBreakShareIndicator,
                        value: controller.todayBreakShareText
                    )
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

                Text(controller.autoPauseSummaryText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(GlazeTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
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

    private func statsTile(title: String, value: String, detail: String) -> some View {
        statsTileSurface {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlazeTheme.textMuted)

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(GlazeTheme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(GlazeTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
    }

    private func shareStatsTile(indicator: BreakShareIndicator, value: String) -> some View {
        statsTileSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("Share")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlazeTheme.textMuted)

                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(shareColor(for: indicator.level))
                        .frame(width: 12, height: 12)

                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GlazeTheme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                VStack(alignment: .leading, spacing: 6) {
                    shareLegendRow(
                        title: "Red",
                        threshold: "< 0.5%",
                        color: GlazeTheme.signalRed,
                        isActive: indicator.level == .warning
                    )

                    shareLegendRow(
                        title: "Orange",
                        threshold: "< 1.0%",
                        color: GlazeTheme.accentAmber,
                        isActive: indicator.level == .caution
                    )

                    shareLegendRow(
                        title: "Green",
                        threshold: ">= 1.0%",
                        color: GlazeTheme.signalGreen,
                        isActive: indicator.level == .healthy
                    )
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func statsTileSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GlazeTheme.rowFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlazeTheme.stroke, lineWidth: 1)
                    )
            )
    }

    private func shareLegendRow(
        title: String,
        threshold: String,
        color: Color,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.system(size: 10, weight: isActive ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isActive ? GlazeTheme.textPrimary : GlazeTheme.textMuted)

            Text(threshold)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isActive ? GlazeTheme.textSecondary : GlazeTheme.textMuted)
                .monospacedDigit()
        }
    }

    private func shareColor(for level: BreakShareIndicator.Level) -> Color {
        switch level {
        case .warning:
            return GlazeTheme.signalRed
        case .caution:
            return GlazeTheme.accentAmber
        case .healthy:
            return GlazeTheme.signalGreen
        }
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
