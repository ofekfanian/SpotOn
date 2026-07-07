import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var appeared = false

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.12) : Color.lightBg)
                .ignoresSafeArea()

            OrbitingLetters(appeared: appeared)

            Image("MagnifyingGlass")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .saturation(1.6).contrast(1.1).brightness(0.04)
                .shadow(color: Color.crystalBlue.opacity(0.5), radius: 30)
                .scaleEffect(appeared ? 1 : 0.7)

            VStack {
                Spacer()
                Text("Master English, One Word at a Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 80)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }
}

// MARK: - Orbiting Letters

private struct LetterItem: Identifiable {
    let id: Int
    let char: String
    let angle: Double
    let radius: CGFloat
    let fontSize: CGFloat
    let colorIndex: Int
}

private struct OrbitingLetters: View {
    let appeared: Bool

    private let palette: [Color] = [
        Color(red: 0.36, green: 0.66, blue: 0.85),
        Color(red: 0.32, green: 0.79, blue: 0.66),
        Color(red: 0.83, green: 0.66, blue: 0.25),
        Color(red: 0.8,  green: 0.2,  blue: 0.3),
        Color(red: 0.3,  green: 0.7,  blue: 0.4),
        Color(red: 0.7,  green: 0.4,  blue: 0.9)
    ]

    private var letters: [LetterItem] {
        var result: [LetterItem] = []
        var idx = 0

        func add(_ chars: [String], radius: CGFloat, size: CGFloat,
                 offset: Double = 0, sizes: [CGFloat]? = nil) {
            for (i, c) in chars.enumerated() {
                let angle = Double(i) / Double(chars.count) * 360.0 + offset
                result.append(LetterItem(
                    id: idx, char: c, angle: angle, radius: radius,
                    fontSize: sizes?[i] ?? size, colorIndex: i % 6
                ))
                idx += 1
            }
        }

        add(["S","p","o","t","O","n"], radius: 115, size: 18)
        add(["W","X","Y","Z","3","9","Q","V","2","7","&","$"], radius: 150, size: 17, offset: 15)
        add(["P","C","R","J","E","F","A","N","Z","U","D","Y","B","K","H","L"],
            radius: 185, size: 20,
            sizes: [22,20,21,19,22,20,23,21,20,19,21,20,23,18,20,19])
        add(["G","I","M","O","Q","S","T","V","W","X","2","&","7","4","8","5","6","!","?","+"],
            radius: 265, size: 17, offset: 9)
        add(["A","E","N","Z","C","D","F","G","A","B","E","J","A","Z","N","A","E","A"],
            radius: 340, size: 15, offset: 5)

        return result
    }

    var body: some View {
        ZStack {
            ForEach(letters) { item in
                let rad = item.angle * .pi / 180
                let x   = item.radius * CGFloat(cos(rad))
                let y   = item.radius * CGFloat(sin(rad))
                Text(item.char)
                    .font(.system(size: item.fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(palette[item.colorIndex].opacity(0.6))
                    .rotationEffect(.degrees(item.angle + 90))
                    .offset(x: appeared ? x : 0, y: appeared ? y : 0)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 1.2, dampingFraction: 0.75)
                        .delay(Double(item.id) * 0.015), value: appeared)
            }
        }
    }
}

#Preview("Dark")  { SplashView().preferredColorScheme(.dark) }
#Preview("Light") { SplashView().preferredColorScheme(.light) }
