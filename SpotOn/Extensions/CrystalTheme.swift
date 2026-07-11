import SwiftUI

// MARK: - App Appearance (Light / Dark / System)
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatic"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Crystal Color Palette
extension Color {
    static let crystalBlue  = Color(hex: "5BA8D9")
    static let crystalMint  = Color(hex: "52C9A8")
    static let crystalGold  = Color(hex: "D4A840")
    static let darkBg       = Color(hex: "23262F")
    static let lightBg      = Color(hex: "F2F3F7")
}

// MARK: - Crystal Gradient
extension LinearGradient {
    static let crystal = LinearGradient(
        stops: [
            .init(color: Color.crystalBlue, location: 0.0),
            .init(color: Color.crystalMint, location: 0.55),
            .init(color: Color.crystalGold, location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let crystalShort = LinearGradient(
        colors: [Color.crystalBlue, Color.crystalMint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Scattered Letters Background
struct ScatteredLettersBackground: View {
    @Environment(\.colorScheme) private var scheme

    private let items: [(String, CGFloat, CGFloat, Double, CGFloat, Double)] = [
        ("A", 0.07, 0.08, -28, 22, 0.55), ("B", 0.88, 0.06, 14, 18, 0.40),
        ("C", 0.18, 0.20, -50, 20, 0.35), ("D", 0.92, 0.22, 30, 16, 0.50),
        ("E", 0.04, 0.45, -15, 24, 0.40), ("F", 0.84, 0.42, -38, 19, 0.55),
        ("G", 0.12, 0.72, 44, 17, 0.35), ("H", 0.78, 0.68, -22, 21, 0.45),
        ("I", 0.50, 0.04, 20, 14, 0.45), ("J", 0.44, 0.94, -30, 18, 0.35),
        ("K", 0.30, 0.35, 18, 16, 0.40), ("L", 0.68, 0.30, -42, 20, 0.50),
        ("M", 0.25, 0.80, 35, 18, 0.35), ("N", 0.72, 0.85, 22, 16, 0.40),
        ("Z", 0.60, 0.12, -18, 15, 0.30), ("S", 0.94, 0.58, 10, 20, 0.35),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let (letter, xF, yF, rot, size, opBase) = item
                let opacity = scheme == .dark ? opBase * 1.2 : opBase * 0.75
                Text(letter)
                    .font(.system(size: size, weight: .light, design: .serif))
                    .foregroundStyle(LinearGradient.crystal)
                    .opacity(min(opacity, 1.0))
                    .rotationEffect(.degrees(rot))
                    .position(x: geo.size.width * xF, y: geo.size.height * yF)
            }
        }
        .drawingGroup()   // flatten all letters into one GPU layer — cheap to composite
        .allowsHitTesting(false)
    }
}

// MARK: - CrystalText
struct CrystalText: View {
    let text: String
    var font: Font = .largeTitle.bold()
    var body: some View {
        Text(text).font(font).foregroundStyle(LinearGradient.crystal)
    }
}

// MARK: - SpotOn Logo
struct SpotOnLogoView: View {
    var height: CGFloat = 60
    private var fontSize: CGFloat { height * 0.68 }

    var body: some View {
        HStack(spacing: 0) {
            Text("Spot")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
            Text("On")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
        }
        .foregroundStyle(LinearGradient.crystal)
        .frame(height: height)
    }
}

// MARK: - Speak Button
/// Circular pronounce button used on flashcards and SnapLearn results.
struct SpeakButton: View {
    let text: String
    var language: String = "en-US"
    @State private var animate = false

    var body: some View {
        Button {
            SpeechService.shared.speak(text, accent: language)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { animate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { animate = false }
        } label: {
            Image(systemName: "speaker.wave.2.fill").font(.subheadline.bold())
                .foregroundStyle(LinearGradient.crystalShort)
                .padding(10).background(Color.crystalBlue.opacity(0.12))
                .clipShape(Circle()).scaleEffect(animate ? 1.25 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Bar Visibility
// The system tab bar is the app's single navigation bar — always visible.
extension View {
    func applyTabBarVisibility() -> some View {
        toolbar(.visible, for: .tabBar)
    }
}

