import SwiftUI
import GoogleSignIn

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @State private var showSplash = true

    var body: some View {
        content
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme ?? nil)
            .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await authVM.refreshDailyState() }
            }
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
            if authVM.isLoading || (authVM.user != nil && authVM.profileState == .loading) {
                loadingView
            } else if authVM.user == nil {
                AuthView().environmentObject(authVM)
            } else if authVM.profileState == .failed {
                profileErrorView
            } else if !authVM.hasCompletedOnboarding {
                OnboardingView().environmentObject(authVM)
            } else {
                MainTabView().environmentObject(authVM)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.user?.uid)
        .animation(.easeInOut(duration: 0.3), value: authVM.hasCompletedOnboarding)
    }

    private var background: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea()
        }
    }

    private var loadingView: some View {
        ZStack {
            background
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
    }

    /// Shown when the signed-in user's profile couldn't be fetched (usually
    /// offline). Retrying beats dropping a returning user into onboarding.
    private var profileErrorView: some View {
        ZStack {
            background
            VStack(spacing: 18) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48)).foregroundStyle(LinearGradient.crystalShort)
                Text("Couldn't load your profile").font(.title3.bold())
                Text("Check your internet connection and try again.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button { Task { await authVM.retryProfileLoad() } } label: {
                    Text("Try Again").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(LinearGradient.crystal).cornerRadius(16)
                }
                .padding(.horizontal, 40).padding(.top, 6)
                Button("Sign Out") { authVM.signOut() }
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(24)
        }
    }
}

#Preview("Light") { ContentView().preferredColorScheme(.light) }
#Preview("Dark")  { ContentView().preferredColorScheme(.dark) }
