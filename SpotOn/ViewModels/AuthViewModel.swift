import Foundation
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?

    var hasCompletedOnboarding: Bool { userProfile?.hasCompletedOnboarding ?? false }

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        guard !AppEnv.isPreview else { isLoading = false; return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            isLoading = false
            return
        }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.user = user
                self?.isLoading = false
                if let uid = user?.uid {
                    await self?.loadProfile(uid: uid)
                    try? await RealtimeDatabaseService.shared.checkAndUpdateStreak(for: uid)
                    RealtimeDatabaseService.shared.startListening(for: uid)
                }
            }
        }

        // Safety timeout — if Firebase never fires the listener, unblock the UI
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self?.isLoading == true { self?.isLoading = false }
        }
    }

    deinit { if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) } }

    func signIn(email: String, password: String) async {
        do { try await Auth.auth().signIn(withEmail: email, password: password); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func signUp(email: String, password: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let profile = UserProfile(uid: result.user.uid, email: email)
            try await FirestoreService.shared.saveUserProfile(profile)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func signOut() {
        if let uid = user?.uid { RealtimeDatabaseService.shared.stopListening(for: uid) }
        do { try Auth.auth().signOut(); user = nil; userProfile = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func completeOnboarding(level: String) async {
        guard let uid = user?.uid else { return }
        var profile = userProfile ?? UserProfile(uid: uid, email: user?.email ?? "")
        profile.level = level
        profile.nativeLanguage = "he"
        profile.targetLanguage = "en"
        profile.hasCompletedOnboarding = true
        UserDefaults.standard.set("he", forKey: "nativeLanguage")
        UserDefaults.standard.set("en", forKey: "targetLanguage")
        do {
            try await FirestoreService.shared.saveUserProfile(profile)
            userProfile = profile
        } catch { errorMessage = error.localizedDescription }
    }

    /// Re-fetches the Firestore profile (e.g. after friendUIDs change server-side).
    func refreshProfile() async {
        guard let uid = user?.uid else { return }
        await loadProfile(uid: uid)
    }

    private func loadProfile(uid: String) async {
        userProfile = try? await FirestoreService.shared.fetchUserProfile(uid: uid)
        if let p = userProfile {
            UserDefaults.standard.set(p.nativeLanguage ?? "he", forKey: "nativeLanguage")
            UserDefaults.standard.set(p.targetLanguage ?? "en", forKey: "targetLanguage")
        }
    }
}
