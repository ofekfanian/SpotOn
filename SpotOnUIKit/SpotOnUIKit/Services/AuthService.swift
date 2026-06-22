import UIKit
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

// MARK: AuthService
// Central authentication (Email + Apple) and user profile (Firestore: users/{uid}).
class AuthService: NSObject {
    static let shared = AuthService()
    private override init() {}

    private let db = Firestore.firestore()
    private(set) var profile: UserProfile?
    var onChange: (() -> Void)?

    private var handle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private weak var presenter: UIViewController?
    private var appleCompletion: ((String?) -> Void)?

    var uid: String? { Auth.auth().currentUser?.uid }
    var isLoggedIn: Bool { Auth.auth().currentUser != nil }

    func startListening() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.loadProfile(uid: user.uid) {
                    RealtimeDatabaseService.shared.start(uid: user.uid)
                    self.onChange?()
                }
            } else {
                self.profile = nil
                self.onChange?()
            }
        }
    }

    // MARK: Email
    func signIn(email: String, password: String, completion: @escaping (String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            completion(error?.localizedDescription)
        }
    }

    func signUp(email: String, password: String, completion: @escaping (String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error { completion(error.localizedDescription); return }
            if let user = result?.user { self?.createProfileIfNeeded(uid: user.uid, email: email) }
            completion(nil)
        }
    }

    func signOut() {
        RealtimeDatabaseService.shared.stop()
        try? Auth.auth().signOut()
    }

    // MARK: Profile
    private func loadProfile(uid: String, completion: @escaping () -> Void) {
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }
            if let data = snap?.data() {
                self.profile = UserProfile(uid: uid, data: data)
            } else {
                self.profile = UserProfile(uid: uid, email: Auth.auth().currentUser?.email ?? "")
                self.saveProfile()
            }
            self.mirrorLanguages()
            completion()
        }
    }

    private func createProfileIfNeeded(uid: String, email: String) {
        let profile = UserProfile(uid: uid, email: email)
        self.profile = profile
        db.collection("users").document(uid).setData(profile.dict, merge: true)
    }

    func saveProfile() {
        guard let profile else { return }
        db.collection("users").document(profile.uid).setData(profile.dict, merge: true)
        mirrorLanguages()
    }

    func completeOnboarding(native: String, target: String, level: String) {
        if profile == nil, let uid = uid {
            profile = UserProfile(uid: uid, email: Auth.auth().currentUser?.email ?? "")
        }
        profile?.nativeLanguage = native
        profile?.targetLanguage = target
        profile?.level = level
        profile?.hasOnboarded = true
        saveProfile()
    }

    // Mirror to UserDefaults so AppSettings-based UI reads the chosen languages.
    private func mirrorLanguages() {
        guard let profile else { return }
        AppSettings.nativeLanguage = profile.nativeLanguage
        AppSettings.targetLanguage = profile.targetLanguage
    }

    // MARK: Apple Sign In
    func startSignInWithApple(presenting: UIViewController, completion: @escaping (String?) -> Void) {
        presenter = presenting
        appleCompletion = completion
        let nonce = Crypto.randomNonce()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Crypto.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

// MARK: Apple delegates
extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presenter?.view.window ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = cred.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            appleCompletion?("Apple Sign In failed"); return
        }
        let firebaseCred = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: cred.fullName)
        Auth.auth().signIn(with: firebaseCred) { [weak self] result, error in
            if let error { self?.appleCompletion?(error.localizedDescription); return }
            if let user = result?.user {
                self?.db.collection("users").document(user.uid).getDocument { snap, _ in
                    if snap?.exists != true {
                        self?.createProfileIfNeeded(uid: user.uid, email: user.email ?? "")
                    }
                }
            }
            self?.appleCompletion?(nil)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleCompletion?(error.localizedDescription)
    }
}
