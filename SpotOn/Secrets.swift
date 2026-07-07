import Foundation

/// Resolves the Gemini API key from Info.plist (`GeminiAPIKey`), which is
/// populated at build time by `Config/APIKeys.xcconfig` via $(GEMINI_API_KEY).
/// The xcconfig is gitignored — copy `APIKeys.example.xcconfig` and paste
/// your own key. Never hardcode keys in source.
enum Secrets {
    static var geminiAPIKey: String {
        if let key = Bundle.main.infoDictionary?["GeminiAPIKey"] as? String,
           !key.isEmpty, key != "PASTE_YOUR_KEY_HERE" {
            return key
        }
        print("⚠️ [Secrets] Gemini API key missing — set GEMINI_API_KEY in SpotOn/Config/APIKeys.xcconfig. AI features will fail.")
        return ""
    }
}
