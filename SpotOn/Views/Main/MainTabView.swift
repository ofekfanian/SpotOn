import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var wordBankVM = WordBankViewModel()

    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Home", systemImage: "house.fill") }
            WordBankView().tabItem { Label("My Words", systemImage: "book.fill") }
            WordAdderView().tabItem { Label("Add", systemImage: "plus.circle.fill") }
            BlitzLaunchView().tabItem { Label("Blitz", systemImage: "bolt.fill") }
            ChatView().tabItem { Label("Tutor", systemImage: "message.fill") }
            LeaderboardView().tabItem { Label("Friends", systemImage: "person.2.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.crystalBlue)
        .environmentObject(wordBankVM)
        .onAppear {
            if let uid = authVM.user?.uid { wordBankVM.startListening(uid: uid) }
        }
        .onDisappear { wordBankVM.stopListening() }
    }
}
