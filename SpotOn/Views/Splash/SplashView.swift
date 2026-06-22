import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var logoIn = false
    @State private var textIn = false
    @State private var ring = false

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea().opacity(textIn ? 1 : 0)

            VStack(spacing: 22) {
                ZStack {
                    Circle().stroke(LinearGradient.crystal, lineWidth: 3)
                        .frame(width: 130, height: 130)
                        .scaleEffect(ring ? 1.4 : 0.9).opacity(ring ? 0 : 0.8)
                    Circle().fill(.ultraThinMaterial).frame(width: 110, height: 110)
                        .overlay(Circle().strokeBorder(LinearGradient.crystal, lineWidth: 1.5))
                        .shadow(color: Color.crystalBlue.opacity(0.4), radius: 20)
                    Image(systemName: "target").resizable().scaledToFit().frame(width: 50, height: 50)
                        .foregroundStyle(LinearGradient.crystal)
                        .rotationEffect(.degrees(logoIn ? 0 : -90))
                }
                .scaleEffect(logoIn ? 1 : 0.5).opacity(logoIn ? 1 : 0)

                VStack(spacing: 8) {
                    CrystalText(text: "SpotOn", font: .system(size: 44, weight: .bold))
                    Text("Master English, One Word at a Time")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .opacity(textIn ? 1 : 0).offset(y: textIn ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { logoIn = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) { textIn = true }
            withAnimation(.easeOut(duration: 1.1).delay(0.4).repeatForever(autoreverses: false)) { ring = true }
        }
    }
}
