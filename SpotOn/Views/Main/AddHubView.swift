import SwiftUI

struct AddHubView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 20) {
                    Spacer()

                    VStack(spacing: 14) {
                        NavigationLink {
                            WordAdderView()
                                .environmentObject(authVM)
                                .environmentObject(wordBankVM)
                        } label: {
                            addCard(
                                title: "Add Manually",
                                subtitle: "Type a word and let AI enrich it",
                                icon: "pencil.line",
                                color: .crystalBlue
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SnapLearnView()
                                .environmentObject(authVM)
                                .environmentObject(wordBankVM)
                        } label: {
                            addCard(
                                title: "SnapLearn",
                                subtitle: "Point your camera at anything",
                                icon: "camera.viewfinder",
                                color: .crystalMint
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(LinearGradient.crystalShort)
                        CrystalText(text: "Add Word", font: .headline)
                    }
                }
            }
            .applyTabBarVisibility()
        }
    }

    private func addCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.bold()).foregroundColor(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(LinearGradient.crystal.opacity(0.25), lineWidth: 1))
    }

    private var background: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg)
            LinearGradient(colors: [Color.crystalMint.opacity(0.05), Color.crystalBlue.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.ultraThinMaterial).opacity(0.6)
            ScatteredLettersBackground().opacity(0.3)
        }
        .ignoresSafeArea()
    }
}

#Preview("Light") { MainTabView(initialTab: 2).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 2).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
