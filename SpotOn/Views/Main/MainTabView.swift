import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var wordBankVM = WordBankViewModel()
    @State private var selectedTab: Int
    @State private var showDailyQuiz = false

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
            presentDailyQuizIfNeeded()
        }
        .onDisappear { wordBankVM.stopListening() }
        .sheet(isPresented: $showDailyQuiz) {
            DailyQuizView(level: authVM.userProfile?.level ?? "intermediate")
                .environmentObject(authVM)
                .environmentObject(wordBankVM)
        }
    }

    /// Shows the daily 20-word quiz once per calendar day.
    /// The flag is written at presentation time, so closing the quiz
    /// early still counts as today's showing.
    private func presentDailyQuizIfNeeded() {
        let today = DateFormatter.spotDate.string(from: Date())
        guard UserDefaults.standard.string(forKey: "dailyQuizDate") != today else { return }
        UserDefaults.standard.set(today, forKey: "dailyQuizDate")
        // Small delay so the tab bar settles before the cover animates in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showDailyQuiz = true }
    }
}

#Preview("Light") { MainTabView().environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView().environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
