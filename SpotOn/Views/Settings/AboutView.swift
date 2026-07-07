import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var scheme
    private let features: [(String, Color, String, String)] = [
        ("books.vertical.fill", .crystalBlue, "Personal Word Bank", "Save words you hear with context, tags, and translations."),
        ("rectangle.on.rectangle.angled", .crystalMint, "Flashcards", "Study in English and Hebrew. Swipe and flip to learn."),
        ("bolt.fill", .crystalGold, "60-Second Blitz", "Race the clock to test how many words you really know."),
        ("text.append", .crystalBlue, "Sentence Completion", "Fill in the blanks and see the full translation."),
        ("camera.viewfinder", .crystalMint, "Snap & Learn", "Photograph anything and learn its name instantly."),
        ("message.fill", .crystalGold, "AI English Tutor", "Chat or have a voice call to practice real conversation."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(.ultraThinMaterial).frame(width: 100, height: 100)
                            .overlay(Circle().strokeBorder(LinearGradient.crystal, lineWidth: 1.5))
                        Image(systemName: "target").resizable().scaledToFit().frame(width: 46, height: 46)
                            .foregroundStyle(LinearGradient.crystal)
                    }
                    .shadow(color: Color.crystalBlue.opacity(0.3), radius: 18)
                    SpotOnLogoView(height: 62)
                    Text("Master English, One Word at a Time").font(.subheadline).foregroundColor(.secondary)
                    Text("Version 1.0.0").font(.caption).foregroundColor(.secondary)
                }
                .padding(.top, 12)

                Text("SpotOn helps you turn the words you encounter in real life into lasting vocabulary. Capture words, practice them in fun games, and speak with an AI tutor — all in English and Hebrew.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What you can do").font(.headline).padding(.horizontal, 4)
                    ForEach(Array(features.enumerated()), id: \.offset) { _, item in
                        let (icon, color, title, desc) = item
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: icon).font(.title3).foregroundColor(color)
                                .frame(width: 42, height: 42).background(color.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.subheadline.bold())
                                Text(desc).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14).background(.ultraThinMaterial).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text("Built with SwiftUI & Firebase").font(.caption2).foregroundColor(.secondary)
                    Text("© 2026 SpotOn").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.top, 6).padding(.bottom, 30)
            }
        }
        .background {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()
            }
        }
        .navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Light") { NavigationStack { AboutView() }.preferredColorScheme(.light) }
#Preview("Dark")  { NavigationStack { AboutView() }.preferredColorScheme(.dark) }
