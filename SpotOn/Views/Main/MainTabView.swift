import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var wordBankVM = WordBankViewModel()
    @AppStorage("showTabBar") private var showTabBar = true
    @State private var selectedTab: Int

    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView() .tag(0).tabItem { Label("Home",    systemImage: "house.fill") }
                WordBankView()  .tag(1).tabItem { Label("Words",   systemImage: "book.fill") }
                AddHubView()    .tag(2).tabItem { Label("Add",     systemImage: "plus.circle.fill") }
                LearnHubView()  .tag(3).tabItem { Label("Learn",   systemImage: "graduationcap.fill") }
                SettingsView()  .tag(4).tabItem { Label("Profile", systemImage: "person.fill") }
            }
            .tint(Color.crystalBlue)
            .environmentObject(wordBankVM)
            .onAppear {
                if let uid = authVM.user?.uid { wordBankVM.startListening(uid: uid) }
            }
            .onDisappear { wordBankVM.stopListening() }

            if !showTabBar {
                FloatingDock(selectedTab: $selectedTab)
                    .padding(.bottom, 20)
            }
        }
    }
}

private struct FloatingDock: View {
    @Binding var selectedTab: Int

    private let items: [(String, String, Int)] = [
        ("house.fill",         "Home",    0),
        ("book.fill",          "Words",   1),
        ("plus.circle.fill",   "Add",     2),
        ("graduationcap.fill", "Learn",   3),
        ("person.fill",        "Profile", 4),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.2) { icon, label, tag in
                Button { selectedTab = tag } label: {
                    VStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(selectedTab == tag
                                ? AnyShapeStyle(LinearGradient.crystalShort)
                                : AnyShapeStyle(Color.secondary))
                        Text(label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(selectedTab == tag ? .crystalBlue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1))
        .shadow(color: Color.crystalBlue.opacity(0.2), radius: 18, y: 6)
        .padding(.horizontal, 14)
    }
}

#Preview("Light") { MainTabView().environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView().environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
