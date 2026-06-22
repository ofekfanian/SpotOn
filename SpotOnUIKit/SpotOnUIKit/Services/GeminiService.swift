import Foundation

// MARK: GeminiService
// Shared Gemini text + vision generation (used by the AI practice features).
class GeminiService {
    static let shared = GeminiService()
    private init() {}

    private let model = "gemini-1.5-flash"

    func generate(prompt: String, imageData: Data? = nil) async -> String? {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else { return nil }

        var parts: [[String: Any]] = [["text": prompt]]
        if let imageData {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]])
        }
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["maxOutputTokens": 250, "temperature": 0.4]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            return parts?.first?["text"] as? String
        } catch {
            return nil
        }
    }
}
