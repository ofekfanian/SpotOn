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
                let profile = UserProfile(uid: authResult.user.uid, email: authResult.user.email ?? "")
                try await FirestoreService.shared.saveUserProfile(profile)
            }
            errorMessage = nil
        } catch let error as GIDSignInError where error.code == .canceled {
            // user closed the sheet — not an error
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        if let uid = user?.uid { RealtimeDatabaseService.shared.stopListening(for: uid) }
        GIDSignIn.sharedInstance.signOut()
        do { try Auth.auth().signOut(); user = nil; userProfile = nil }
        catch { errorMessage = error.localizedDescription }
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
        errorMessage = nil
        return true
    }

    private func clearLocalState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "chatHistory")
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

    private func loadProfile(uid: String) async {
        userProfile = try? await FirestoreService.shared.fetchUserProfile(uid: uid)
        if let p = userProfile {
            UserDefaults.standard.set(p.nativeLanguage ?? "he", forKey: "nativeLanguage")
            UserDefaults.standard.set(p.targetLanguage ?? "en", forKey: "targetLanguage")
        }
    }
}
