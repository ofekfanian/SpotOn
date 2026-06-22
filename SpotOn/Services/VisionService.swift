import UIKit

/// Identifies the main object in a photo using Gemini Vision (English + Hebrew + French).
final class VisionService {
    static let shared = VisionService()
    private init() {}

    struct Result { let english: String; let hebrew: String; let french: String; let description: String }

    private let apiKey = Secrets.geminiAPIKey
    private let model = "gemini-1.5-flash"

    func identify(image: UIImage) async -> Result? {
        let resized = image.resized(maxDimension: 768)
        guard let jpeg = resized.jpegData(compressionQuality: 0.6) else { return nil }
        let base64 = jpeg.base64EncodedString()

        let prompt = """
        Identify the single main object in this image. \
        Respond with strict minified JSON only, no markdown: \
        {"english":"<object name in English, lowercase, 1-2 words>",\
        "hebrew":"<the same object name in Hebrew>",\
        "french":"<the same object name in French>",\
        "description":"<one short, simple English sentence about it>"}
        """
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [
                ["text": prompt],
                ["inline_data": ["mime_type": "image/jpeg", "data": base64]]
            ]]],
            "generationConfig": ["maxOutputTokens": 150, "temperature": 0.2]
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
            guard var text = parts?.first?["text"] as? String else { return nil }
            text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let inner = text.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: inner) as? [String: Any],
                  let english = parsed["english"] as? String,
                  let hebrew = parsed["hebrew"] as? String else { return nil }
            let french = parsed["french"] as? String ?? ""
            let description = parsed["description"] as? String ?? ""
            return Result(english: english, hebrew: hebrew, french: french, description: description)
        } catch { return nil }
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
