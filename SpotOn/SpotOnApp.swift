import SwiftUI
import SwiftData
import Firebase

@main
struct SpotOnApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ReadingPassage.self, PassageWord.self],
                        isAutosaveEnabled: true) { result in
            guard case .success(let container) = result else { return }
            Task { @MainActor in
                await PassageSeeder.shared.seedIfNeeded(in: container.mainContext)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        return true
    }
}
