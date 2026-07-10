import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var wordBankVM = WordBankViewModel()
    @State private var selectedTab: Int

    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
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
    }
}

#Preview("Light") { MainTabView().environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView().environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
