import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var idiom: Idiom?
    @Published var isLoading = false

    func load(level: String) async {
        isLoading = true
        idiom = IdiomService.shared.today(level: level)   // rotates every 24h, offline
        isLoading = false

        // Cache for the home-screen widget (shared App Group).
        if let idiom {
            let defaults = UserDefaults(suiteName: "group.com.spoton.shared")
            defaults?.set(idiom.text, forKey: "widgetIdiomText")
            defaults?.set(idiom.definition, forKey: "widgetIdiomDef")
        }
    }
}
