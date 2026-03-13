import SwiftUI

enum GlazeTheme {
    static let backgroundTop = Color(red: 0.07, green: 0.05, blue: 0.11)
    static let backgroundBottom = Color(red: 0.03, green: 0.03, blue: 0.07)
    static let surfaceTop = Color(red: 0.15, green: 0.11, blue: 0.21)
    static let surfaceBottom = Color(red: 0.09, green: 0.08, blue: 0.16)
    static let elevatedTop = Color(red: 0.27, green: 0.18, blue: 0.32)
    static let elevatedBottom = Color(red: 0.13, green: 0.10, blue: 0.20)
    static let rowFill = Color.white.opacity(0.045)
    static let rowFillStrong = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.08)
    static let strongStroke = Color.white.opacity(0.14)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.52)
    static let accentPink = Color(red: 0.95, green: 0.34, blue: 0.58)
    static let accentAmber = Color(red: 0.96, green: 0.69, blue: 0.30)
    static let accentPurple = Color(red: 0.49, green: 0.37, blue: 0.95)

    static let appBackground = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [surfaceTop, surfaceBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let elevatedGradient = LinearGradient(
        colors: [elevatedTop, elevatedBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accentPink, accentAmber],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct GlazePanelBackdrop: View {
    var body: some View {
        ZStack {
            GlazeTheme.appBackground

            Circle()
                .fill(GlazeTheme.accentPink.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 90)
                .offset(x: -110, y: -150)

            Circle()
                .fill(GlazeTheme.accentPurple.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 120)
                .offset(x: 120, y: 120)

            Circle()
                .fill(GlazeTheme.accentAmber.opacity(0.14))
                .frame(width: 200, height: 200)
                .blur(radius: 100)
                .offset(x: 90, y: -180)
        }
    }
}

struct GlazeOverlayBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.93),
                    Color(red: 0.10, green: 0.06, blue: 0.16).opacity(0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(GlazeTheme.accentPink.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: 0, y: -130)

            Circle()
                .fill(GlazeTheme.accentPurple.opacity(0.18))
                .frame(width: 520, height: 520)
                .blur(radius: 180)
                .offset(x: 130, y: 210)

            Circle()
                .fill(GlazeTheme.accentAmber.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .offset(x: -220, y: -160)
        }
        .ignoresSafeArea()
    }
}

struct GlazeCardSurface<Content: View>: View {
    private let radius: CGFloat
    private let fill: LinearGradient
    private let padding: CGFloat
    private let content: Content

    init(
        radius: CGFloat = 24,
        fill: LinearGradient = GlazeTheme.surfaceGradient,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.fill = fill
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(GlazeTheme.stroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
            )
    }
}

struct GlazePill: View {
    let icon: String?
    let label: String
    var accented = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(accented ? GlazeTheme.textPrimary : GlazeTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(accented ? GlazeTheme.rowFillStrong : GlazeTheme.rowFill)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accented ? GlazeTheme.strongStroke : GlazeTheme.stroke, lineWidth: 1)
                )
        )
    }
}

struct GlazePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(GlazeTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(GlazeTheme.accentGradient)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(
                        color: GlazeTheme.accentPink.opacity(configuration.isPressed ? 0.12 : 0.24),
                        radius: configuration.isPressed ? 8 : 16,
                        y: configuration.isPressed ? 4 : 8
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlazeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(GlazeTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.07))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(configuration.isPressed ? 0.16 : 0.10), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlazeGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(GlazeTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.09 : 0.04))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
