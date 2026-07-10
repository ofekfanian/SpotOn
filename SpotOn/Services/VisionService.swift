import UIKit

/// Identifies the main object in a photo using Gemini Vision (English + Hebrew).
final class VisionService {
    static let shared = VisionService()
    private init() {}

    struct Result { let english: String; let hebrew: String; let description: String }

    enum Failure: Error {
        case quotaExceeded   // free-tier daily limit hit (HTTP 429)
        case network         // no connection / server error
        case unrecognized    // Gemini answered but couldn't identify the object
    }

    private let apiKey = Secrets.geminiAPIKey
    private let model = "gemini-2.5-flash"

    func identify(image: UIImage) async -> Swift.Result<Result, Failure> {
        let resized = image.resized(maxDimension: 768)
        guard let jpeg = resized.jpegData(compressionQuality: 0.6) else { return .failure(.unrecognized) }
        let base64 = jpeg.base64EncodedString()

        let prompt = """
        Identify the single main object in this image. \
        Respond with strict minified JSON only, no markdown: \
        {"english":"<object name in English, lowercase, 1-2 words>",\
        "hebrew":"<the same object name in Hebrew>",\
        "description":"<one short, simple English sentence about it>"}
        """
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return .failure(.network) }

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [
                ["text": prompt],
                ["inline_data": ["mime_type": "image/jpeg", "data": base64]]
            ]]],
            "generationConfig": ["maxOutputTokens": 150, "temperature": 0.2,
                                 "thinkingConfig": ["thinkingBudget": 0]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.network) }
            if http.statusCode == 429 { return .failure(.quotaExceeded) }
            guard http.statusCode == 200 else { return .failure(.network) }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            guard var text = parts?.first?["text"] as? String else { return .failure(.unrecognized) }
            text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let inner = text.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: inner) as? [String: Any],
                  let english = parsed["english"] as? String,
                  let hebrew = parsed["hebrew"] as? String else { return .failure(.unrecognized) }
            let description = parsed["description"] as? String ?? ""
            return .success(Result(english: english, hebrew: hebrew, description: description))
        } catch { return .failure(.network) }
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
