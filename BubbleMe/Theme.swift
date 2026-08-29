import SwiftUI

enum Palette {
    static let bg = Color(red: 0.027, green: 0.043, blue: 0.078)
    static let surface = Color(red: 0.071, green: 0.094, blue: 0.165)
    static let surface2 = Color(red: 0.102, green: 0.133, blue: 0.220)
    static let fg = Color(red: 0.957, green: 0.937, blue: 0.902)
    static let muted = Color(red: 0.604, green: 0.639, blue: 0.722)
    static let accent = Color(red: 1, green: 0.353, blue: 0.478)
    static let aqua = Color(red: 0.180, green: 0.902, blue: 0.773)
    static let border = Color.white.opacity(0.12)

    static let bubble: [Color] = [
        Color(red: 1, green: 0.30, blue: 0.42),
        Color(red: 1, green: 0.69, blue: 0.13),
        Color(red: 0.23, green: 0.63, blue: 1),
        Color(red: 0.13, green: 0.83, blue: 0.77),
        Color(red: 0.61, green: 0.42, blue: 1),
    ]
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Palette.accent.opacity(0.28), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16, weight: .semibold))
            .foregroundStyle(Palette.fg)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct StarryBackdrop: View {
    var body: some View {
        ZStack {
            Palette.bg
            Image("Twilight")
                .resizable()
                .scaledToFill()
                .opacity(0.55)
            LinearGradient(
                colors: [Palette.bg.opacity(0.15), Palette.bg.opacity(0.55), Palette.bg],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
