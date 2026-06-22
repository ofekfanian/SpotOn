import Foundation
import FirebaseAuth
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?

    var hasCompletedOnboarding: Bool { userProfile?.hasCompletedOnboarding ?? false }

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

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

    func completeOnboarding(level: String, native: String = "he", target: String = "en") async {
        guard let uid = user?.uid else { return }
        var profile = userProfile ?? UserProfile(uid: uid, email: user?.email ?? "")
        profile.level = level
        profile.nativeLanguage = native
        profile.targetLanguage = target
        profile.hasCompletedOnboarding = true
        UserDefaults.standard.set(native, forKey: "nativeLanguage")
        UserDefaults.standard.set(target, forKey: "targetLanguage")
        do {
            try await FirestoreService.shared.saveUserProfile(profile)
            userProfile = profile
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Apple Sign In
    func prepareAppleRequest() -> String {
        let nonce = String.randomNonce()
        currentNonce = nonce
        return nonce.sha256Hash
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let token = cred.identityToken,
                  let tokenStr = String(data: token, encoding: .utf8) else {
                errorMessage = "Apple Sign In failed"; return
            }
            let firebaseCred = OAuthProvider.appleCredential(withIDToken: tokenStr, rawNonce: nonce, fullName: cred.fullName)
            do {
                let res = try await Auth.auth().signIn(with: firebaseCred)
                if try await FirestoreService.shared.fetchUserProfile(uid: res.user.uid) == nil {
                    let profile = UserProfile(uid: res.user.uid, email: res.user.email ?? "")
                    try await FirestoreService.shared.saveUserProfile(profile)
                }
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadProfile(uid: String) async {
        userProfile = try? await FirestoreService.shared.fetchUserProfile(uid: uid)
        if let p = userProfile {
            UserDefaults.standard.set(p.nativeLanguage ?? "he", forKey: "nativeLanguage")
            UserDefaults.standard.set(p.targetLanguage ?? "en", forKey: "targetLanguage")
        }
    }
}
