import Foundation

// MARK: - Result type

struct WordEnrichment {
    let definition: String
    let partOfSpeech: String    // noun / verb / adjective / adverb / …
    let level: String           // A1–C2
    let hebrew: String          // Hebrew translation
    let phonetic: String        // simple respelling, e.g. "know -> no"
    let exampleBusiness: String
    let exampleCasual: String
    let exampleTech: String
    let relatedIdiom: String
}

// MARK: - Service

/// Calls Gemini 1.5 Flash to enrich a user-added word with structured metadata.
/// All network work is performed off the main thread via async/await.
final class LLMEnrichmentService {
    static let shared = LLMEnrichmentService()

    private let endpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private init() {}

    func enrich(word: String) async throws -> WordEnrichment {
        let url = try buildURL()
        let request = try buildRequest(url: url, word: word)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw EnrichmentError.badResponse
        }

        return try parseResponse(data: data)
    }

    // MARK: - Request helpers

    private func buildURL() throws -> URL {
        guard var components = URLComponents(string: endpoint) else {
            throw EnrichmentError.badURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: Secrets.geminiAPIKey)]
        guard let url = components.url else { throw EnrichmentError.badURL }
        return url
    }

    private func buildRequest(url: URL, word: String) throws -> URLRequest {
        let prompt = """
        For the English word "\(word)", respond ONLY with a valid JSON object. \
        No markdown, no code fences, no extra text outside the JSON.
        Use exactly this structure:
        {
          "definition": "clear concise definition in simple English",
          "partOfSpeech": "noun",
          "level": "B1",
          "hebrew": "the Hebrew translation of the word",
          "phonetic": "a simple pronunciation respelling using plain English letters, like 'noh' for know or 'suh-REN-dip-ih-tee' for serendipity",
          "examples": {
            "business": "example sentence in a professional/business context",
            "casual": "example sentence in casual everyday conversation",
            "tech": "example sentence in a technology or software context"
          },
          "relatedIdiom": "a common English idiom or phrase that relates to this word"
        }
        The level field must be one of: A1, A2, B1, B2, C1, C2.
        """

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 450,
                "responseMimeType": "application/json",
                "thinkingConfig": ["thinkingBudget": 0]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response parsing

    private func parseResponse(data: Data) throws -> WordEnrichment {
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let gemini = try JSONDecoder().decode(GeminiResponse.self, from: data)
        var rawText = gemini.candidates.first?.content.parts.first?.text ?? "{}"

        // Strip any stray markdown fences Gemini might add despite responseMimeType
        rawText = rawText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = rawText.data(using: .utf8) else {
            throw EnrichmentError.parseFailure
        }

        struct Payload: Decodable {
            struct Examples: Decodable {
                let business: String
                let casual: String
                let tech: String
            }
            let definition: String
            let partOfSpeech: String
            let level: String
            let hebrew: String?
            let phonetic: String?
            let examples: Examples
            let relatedIdiom: String
        }

        let p = try JSONDecoder().decode(Payload.self, from: jsonData)
        return WordEnrichment(
            definition: p.definition,
            partOfSpeech: p.partOfSpeech,
            level: p.level,
            hebrew: p.hebrew ?? "",
            phonetic: p.phonetic ?? "",
            exampleBusiness: p.examples.business,
            exampleCasual: p.examples.casual,
            exampleTech: p.examples.tech,
            relatedIdiom: p.relatedIdiom
        )
    }
}

// MARK: - Errors

enum EnrichmentError: LocalizedError {
    case badURL, badResponse, parseFailure

    var errorDescription: String? {
        switch self {
        case .badURL:        return "Invalid enrichment API URL"
        case .badResponse:   return "Gemini returned a non-200 response"
        case .parseFailure:  return "Could not parse enrichment JSON"
        }
    }
}
