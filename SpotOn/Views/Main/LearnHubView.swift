import SwiftUI

struct LearnHubView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        modeCard(title: "Reading Pathways", subtitle: "Contextual passages by level",
                                 icon: "book.pages.fill", color: .crystalBlue) {
                            ReadingPathwayView()
                                .environmentObject(authVM)
                                .environmentObject(wordBankVM)
                        }
                        modeCard(title: "Blitz", subtitle: "60-second word race",
                                 icon: "timer", color: .crystalGold) {
                            BlitzLaunchView()
                                .environmentObject(authVM)
                                .environmentObject(wordBankVM)
                        }
                        modeCard(title: "Flashcards", subtitle: "Flip and memorise",
                                 icon: "rectangle.on.rectangle.angled", color: .crystalMint) {
                            FlashcardsView(words: wordBankVM.words)
                                .environmentObject(authVM)
                        }
                        modeCard(title: "Sentences", subtitle: "Fill in the blank",
                                 icon: "text.append", color: .crystalBlue) {
                            SentenceCompletionView(level: authVM.userProfile?.level ?? "intermediate")
                                .environmentObject(authVM)
                        }
                        modeCard(title: "Tutor", subtitle: "Chat with your AI tutor",
                                 icon: "message.fill", color: .crystalGold) {
                            ChatView()
                                .environmentObject(authVM)
                                .environmentObject(wordBankVM)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundStyle(LinearGradient.crystalShort)
                        CrystalText(text: "Learn", font: .headline)
                    }
                }
            }
            .applyTabBarVisibility()
        }
    }

    @ViewBuilder
    private func modeCard<Dest: View>(
        title: String, subtitle: String,
        icon: String, color: Color,
        @ViewBuilder destination: () -> Dest
    ) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.bold()).foregroundColor(.primary)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold()).foregroundColor(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(LinearGradient.crystal.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg)
            LinearGradient(colors: [Color.crystalBlue.opacity(0.05), Color.crystalMint.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.ultraThinMaterial).opacity(0.6)
            ScatteredLettersBackground().opacity(0.3)
        }
        .ignoresSafeArea()
    }
}

#Preview("Light") { MainTabView(initialTab: 3).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 3).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
