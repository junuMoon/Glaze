import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: GlazeController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Glaze")
                    .font(.title3.weight(.semibold))

                Text(controller.phaseTitleText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(controller.countdownText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(controller.phaseDetailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            actionSection

            Divider()

            settingsSection

            Divider()

            HStack {
                Button("Reset Cycle") {
                    controller.resetCycle()
                }

                Spacer()

                Button("Quit") {
                    controller.quit()
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder
    private var actionSection: some View {
        switch controller.snapshot.phase {
        case .working:
            HStack {
                Button("Pause") {
                    controller.pauseOrResume()
                }
                Button("Start Break Now") {
                    controller.startBreakNow()
                }
            }
        case .headsUp:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Snooze 1m") {
                        controller.snoozeOneMinute()
                    }
                    Button("Start Break") {
                        controller.startBreakNow()
                    }
                }

                Button("Skip This Break") {
                    controller.skipBreak()
                }
            }
        case .breaking:
            HStack {
                Button("Pause") {
                    controller.pauseOrResume()
                }
                Button("Skip Break") {
                    controller.skipBreak()
                }
            }
        case .paused:
            HStack {
                Button("Resume") {
                    controller.pauseOrResume()
                }
                Button("Reset Cycle") {
                    controller.resetCycle()
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timer Settings")
                .font(.subheadline.weight(.semibold))

            Stepper(
                value: Binding(
                    get: { controller.settings.workMinutes },
                    set: { controller.updateWorkMinutes($0) }
                ),
                in: 5...90
            ) {
                settingRow(
                    title: "Work",
                    value: "\(controller.settings.workMinutes) min"
                )
            }

            Stepper(
                value: Binding(
                    get: { controller.settings.breakSeconds },
                    set: { controller.updateBreakSeconds($0) }
                ),
                in: 10...300,
                step: 5
            ) {
                settingRow(
                    title: "Break",
                    value: "\(controller.settings.breakSeconds) sec"
                )
            }

            Stepper(
                value: Binding(
                    get: { controller.settings.headsUpSeconds },
                    set: { controller.updateHeadsUpSeconds($0) }
                ),
                in: 0...120,
                step: 5
            ) {
                settingRow(
                    title: "Heads-up",
                    value: "\(controller.settings.headsUpSeconds) sec"
                )
            }
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
