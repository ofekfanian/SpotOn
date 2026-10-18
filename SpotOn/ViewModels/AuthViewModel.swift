import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

// MARK: - Level progression
/// The user's level starts at the placement-test result and is promoted
/// automatically as XP accumulates. It never goes down.
enum LevelSystem {
    static let order = ["beginner", "intermediate", "advanced"]

    static func rank(_ level: String) -> Int { order.firstIndex(of: level) ?? 0 }

    /// Level implied purely by XP.
    static func xpLevel(_ xp: Int) -> String {
        switch xp {
        case ..<600:    return "beginner"
        case ..<1800:   return "intermediate"
        default:        return "advanced"
        }
    }

    /// XP still needed to reach the next level, nil when maxed out.
    static func xpToNext(_ xp: Int) -> Int? {
        switch xp {
        case ..<600:  return 600 - xp
        case ..<1800: return 1800 - xp
        default:      return nil
        }
    }

    /// Effective level: the higher of the stored level and the XP level.
    static func effective(stored: String, xp: Int) -> String {
        let a = rank(stored), b = rank(xpLevel(xp))
        return order[max(a, b)]
    }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?

    /// Where the signed-in user's Firestore profile stands. The UI waits on
    /// `.loading` and offers a retry on `.failed`, so a returning user is never
    /// mistaken for a new one and sent back through onboarding.
    enum ProfileState { case idle, loading, loaded, failed }
    @Published var profileState: ProfileState = .idle

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
                guard let self else { return }
                self.user = user
                guard let uid = user?.uid else {
                    self.userProfile = nil
                    self.profileState = .idle
                    self.isLoading = false
                    return
                }
                await self.loadProfile(uid: uid)
                self.isLoading = false
                try? await RealtimeDatabaseService.shared.checkAndUpdateStreak(for: uid)
                RealtimeDatabaseService.shared.startListening(for: uid)
            }
        }

        // Safety timeout — if Firebase never fires the listener, unblock the UI
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if self?.isLoading == true { self?.isLoading = false }
        }
    }

    deinit { if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) } }

    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."; return
        }
        do { try await Auth.auth().signIn(withEmail: email, password: password); errorMessage = nil }
        catch { errorMessage = friendlyMessage(for: error) }
    }

    func signUp(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and a password."; return
        }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let profile = UserProfile(uid: result.user.uid, email: email)
            try await FirestoreService.shared.saveUserProfile(profile)
            userProfile = profile
            profileState = .loaded
            errorMessage = nil
        } catch { errorMessage = friendlyMessage(for: error) }
    }

    /// Sends a password-reset email. Returns true when the email was sent.
    func sendPasswordReset(email: String) async -> Bool {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { errorMessage = "Enter your email first."; return false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = nil
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    /// Maps the common Firebase Auth errors to short, readable messages.
    private func friendlyMessage(for error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail:                     return "That email address doesn't look right."
        case .wrongPassword, .invalidCredential: return "Wrong email or password."
        case .userNotFound:                     return "No account found with that email."
        case .emailAlreadyInUse:                return "An account with this email already exists. Try signing in."
        case .weakPassword:                     return "Choose a stronger password (at least 6 characters)."
        case .networkError:                     return "No connection. Check your internet and try again."
        case .tooManyRequests:                  return "Too many attempts. Please wait a moment and try again."
        default:                                return error.localizedDescription
        }
    }

    // MARK: - Google Sign-In

    /// True when the Firebase config includes an OAuth client
    /// (requires the Google provider to be enabled in the Firebase console).
    var isGoogleSignInAvailable: Bool {
        FirebaseApp.app()?.options.clientID != nil
    }

    @MainActor
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In isn't configured yet."
            return
        }
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google Sign-In failed."; return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            if try await FirestoreService.shared.fetchUserProfile(uid: authResult.user.uid) == nil {
                let profile = UserProfile(uid: authResult.user.uid, email: authResult.user.email ?? "",
                                          displayName: authResult.user.displayName ?? "")
                try await FirestoreService.shared.saveUserProfile(profile)
                userProfile = profile
                profileState = .loaded
            }
            errorMessage = nil
        } catch let error as GIDSignInError where error.code == .canceled {
            // user closed the sheet — not an error
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signOut() {
        if let uid = user?.uid { RealtimeDatabaseService.shared.stopListening(for: uid) }
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
            user = nil; userProfile = nil; profileState = .idle
            AchievementTracker.reset()   // the next account starts its own badge history
        } catch { errorMessage = error.localizedDescription }
    }

    /// Re-runs the once-a-day work when the app returns to the foreground,
    /// so the streak also advances when the app stayed open overnight.
    func refreshDailyState() async {
        guard let uid = user?.uid else { return }
        if profileState == .failed { await loadProfile(uid: uid) }
        try? await RealtimeDatabaseService.shared.checkAndUpdateStreak(for: uid)
    }

    /// Retry button on the "couldn't load your profile" screen.
    func retryProfileLoad() async {
        guard let uid = user?.uid else { return }
        await loadProfile(uid: uid)
    }

    // MARK: - Account deletion

    /// Permanently deletes the account: Firestore data, RTDB data, the Auth
    /// user, and all local state. Returns true on full success.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let firebaseUser = user else { return false }
        let uid = firebaseUser.uid

        RealtimeDatabaseService.shared.stopListening(for: uid)

        // Ghost-session check: if the account was already deleted server-side
        // (e.g. via the Firebase console), the cached session can't authenticate.
        // There is nothing to delete remotely — just clean up locally.
        do {
            _ = try await firebaseUser.getIDToken(forcingRefresh: true)
        } catch {
            clearLocalState()
            signOut()
            errorMessage = nil
            return true
        }
        // Best-effort cloud cleanup: each store is attempted independently so a
        // rules problem in one store never blocks deleting the account itself.
        do {
            try await FirestoreService.shared.deleteAllUserData(uid: uid)
        } catch {
            print("[DeleteAccount] Firestore cleanup failed: \(error)")
        }
        do {
            try await RealtimeDatabaseService.shared.deleteUserData(uid: uid)
        } catch {
            print("[DeleteAccount] RTDB cleanup failed: \(error)")
        }

        do {
            try await firebaseUser.delete()
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            // Firebase requires a fresh login for destructive actions.
            errorMessage = "For security, please sign in again and then delete your account."
            signOut()
            return false
        } catch {
            errorMessage = error.localizedDescription
            signOut()
            return false
        }

        clearLocalState()
        GIDSignIn.sharedInstance.signOut()
        user = nil
        userProfile = nil
        profileState = .idle
        errorMessage = nil
        return true
    }

    private func clearLocalState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "chatHistory")
        defaults.removeObject(forKey: "dailyQuizDate")
        AchievementTracker.reset()
        for level in LevelSystem.order {
            defaults.removeObject(forKey: "flashSeen_\(level)")
            defaults.removeObject(forKey: "flashDealt_\(level)")
        }
        ProfileImageStore.shared.remove()
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
            profileState = .loaded
        } catch { errorMessage = error.localizedDescription }
    }

    /// Promotes the stored level when accumulated XP crosses a threshold.
    /// Returns the new level name if a promotion happened (for the level-up banner).
    func autoPromoteLevel(xp: Int) async -> String? {
        guard var profile = userProfile else { return nil }
        let promoted = LevelSystem.effective(stored: profile.level, xp: xp)
        guard LevelSystem.rank(promoted) > LevelSystem.rank(profile.level) else { return nil }
        profile.level = promoted
        userProfile = profile
        try? await FirestoreService.shared.saveUserProfile(profile)
        return promoted
    }

    /// Updates the user's display name in the profile.
    func updateDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var profile = userProfile else { return }
        profile.username = trimmed
        userProfile = profile
        try? await FirestoreService.shared.saveUserProfile(profile)
    }

    /// Re-fetches the Firestore profile (e.g. after friendUIDs change server-side).
    func refreshProfile() async {
        guard let uid = user?.uid else { return }
        await loadProfile(uid: uid)
    }

    /// Fetches the profile with a couple of quick retries. A missing document
    /// means a brand-new user (onboarding); a network error means "try again",
    /// never "start over" — onboarding would overwrite the existing profile.
    private func loadProfile(uid: String) async {
        profileState = .loading
        for attempt in 0..<3 {
            do {
                let profile = try await FirestoreService.shared.fetchUserProfile(uid: uid)
                guard user?.uid == uid else { return }   // signed out meanwhile
                userProfile = profile
                profileState = .loaded
                if let p = profile {
                    UserDefaults.standard.set(p.nativeLanguage ?? "he", forKey: "nativeLanguage")
                    UserDefaults.standard.set(p.targetLanguage ?? "en", forKey: "targetLanguage")
                }
                return
            } catch {
                print("[Auth] Profile load attempt \(attempt + 1) failed: \(error.localizedDescription)")
                if attempt < 2 { try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000) }
            }
        }
        if user?.uid == uid { profileState = .failed }
    }
}
