import UIKit

// MARK: SceneDelegate
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.tintColor = .crystalBlue
        window.overrideUserInterfaceStyle = AppSettings.appearance.interfaceStyle
        window.makeKeyAndVisible()
        self.window = window

        // Rebuild the root whenever auth state changes.
        AuthService.shared.onChange = { [weak self] in self?.updateRoot() }
        AuthService.shared.startListening()
        updateRoot()
    }

    private func updateRoot() {
        let root: UIViewController
        if !AuthService.shared.isLoggedIn {
            root = AuthController()
        } else if AuthService.shared.profile?.hasOnboarded != true {
            root = makeOnboarding()
        } else {
            root = makeTabBar()
        }
        guard let window else { return }
        if window.rootViewController == nil {
            window.rootViewController = root
        } else {
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
                window.rootViewController = root
            }
        }
    }

    private func makeOnboarding() -> UIViewController {
        let vc = OnboardingController()
        vc.onDone = { [weak self] in self?.updateRoot() }
        return vc
    }

    private func makeTabBar() -> UITabBarController {
        let tabs = UITabBarController()
        tabs.viewControllers = [
            nav(HomeController(), title: "Home", icon: "house.fill"),
            nav(WordsController(), title: "Words", icon: "book.fill"),
            nav(PracticeController(), title: "Practice", icon: "gamecontroller.fill"),
            nav(ChatController(), title: "Tutor", icon: "message.fill"),
            nav(LeaderboardController(), title: "Friends", icon: "person.2.fill"),
            nav(SettingsController(), title: "Settings", icon: "gearshape.fill"),
        ]
        return tabs
    }

    private func nav(_ root: UIViewController, title: String, icon: String) -> UINavigationController {
        root.title = title
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), selectedImage: nil)
        return nav
    }
}
