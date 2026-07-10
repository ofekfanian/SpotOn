import SwiftUI
import GoogleSignIn

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @Environment(\.colorScheme) private var scheme
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @State private var showSplash = true

    var body: some View {
        content
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme ?? nil)
            .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
    }

    @ViewBuilder
    private var content: some View {
        if showSplash {
            SplashView()
                .transition(.opacity)
                .task {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        Group {
            if authVM.isLoading {
                ZStack {
                    (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                    ScatteredLettersBackground().ignoresSafeArea()
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 88, height: 88)
                            Image(systemName: "target").resizable().scaledToFit().frame(width: 40, height: 40)
                                .foregroundStyle(LinearGradient.crystal)
                        }
                        SpotOnLogoView(height: 54)
                        ProgressView().tint(Color.crystalBlue)
                    }
                }
            } else if authVM.user == nil {
                AuthView().environmentObject(authVM)
            } else if !authVM.hasCompletedOnboarding {
                OnboardingView().environmentObject(authVM)
            } else {
                MainTabView().environmentObject(authVM)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.user?.uid)
        .animation(.easeInOut(duration: 0.3), value: authVM.hasCompletedOnboarding)
    }
}

#Preview("Light") { ContentView().preferredColorScheme(.light) }
#Preview("Dark")  { ContentView().preferredColorScheme(.dark) }
