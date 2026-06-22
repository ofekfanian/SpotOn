import UIKit

// MARK: AppAppearance
enum AppAppearance: Int, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return "Automatic"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: Language
enum Language: String, CaseIterable {
    case english = "en"
    case hebrew  = "he"
    case french  = "fr"

    var name: String {
        switch self {
        case .english: return "English"
        case .hebrew:  return "Hebrew"
        case .french:  return "French"
        }
    }
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .hebrew:  return "עברית"
        case .french:  return "Français"
        }
    }
    var speechCode: String {
        switch self {
        case .english: return "en-US"
        case .hebrew:  return "he-IL"
        case .french:  return "fr-FR"
        }
    }
    var isRTL: Bool { self == .hebrew }
}

// MARK: AppSettings
enum AppSettings {
    private static let key = "appearance"

    static var appearance: AppAppearance {
        get { AppAppearance(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            applyAppearance()
        }
    }

    // MARK: Languages (chosen in onboarding)
    static var nativeLanguage: String {
        get { UserDefaults.standard.string(forKey: "nativeLanguage") ?? "he" }
        set { UserDefaults.standard.set(newValue, forKey: "nativeLanguage") }
    }
    static var targetLanguage: String {
        get { UserDefaults.standard.string(forKey: "targetLanguage") ?? "en" }
        set { UserDefaults.standard.set(newValue, forKey: "targetLanguage") }
    }
    static var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: "hasOnboarded") }
        set { UserDefaults.standard.set(newValue, forKey: "hasOnboarded") }
    }

    // Applies the chosen style to all connected windows.
    static func applyAppearance() {
        let style = appearance.interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}
