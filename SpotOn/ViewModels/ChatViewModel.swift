import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiKey = Secrets.geminiAPIKey
    private let model = "gemini-1.5-flash"
    private let maxHistory = 10
    private let storageKey = "chatHistory"
    private var lastFailedText: String?

    private let greeting = ChatMessage(role: "assistant",
        content: "Hey! I'm your SpotOn English tutor. What would you like to talk about today?")

    private let systemPromptText = """
        You are an expert, friendly English tutor inside an iOS app named SpotOn. \
        Keep responses short, natural, and conversational (1-2 sentences max). \
        If the user makes a mistake, gently point it out at the end. \
        Always ask a follow-up question. Avoid overly academic words.
        """

    init() {
        load()
        if messages.isEmpty { messages = [greeting] }
    }

    func sendMessage(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: "user", content: trimmed))
        await requestReply(for: trimmed)
    }

    func retry() async {
        guard let text = lastFailedText else { return }
        await requestReply(for: text)
    }

    func clearConversation() {
        messages = [greeting]; errorMessage = nil; lastFailedText = nil; save()
    }

    func speak(_ message: ChatMessage) { SpeechService.shared.speak(message.content, accent: "en-US") }

    private func requestReply(for text: String) async {
        isLoading = true; errorMessage = nil; lastFailedText = nil; save()
        do {
            let reply = try await callGemini()
            messages.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            errorMessage = "Could not reach tutor. Check your connection."
            lastFailedText = text
        }
        isLoading = false; save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return }
        messages = saved
    }

    private func save() {
        if let data = try? JSONEncoder().encode(messages) { UserDefaults.standard.set(data, forKey: storageKey) }
    }

    private func contextWindow() -> [ChatMessage] {
        messages.filter { $0.role != "system" }.suffix(maxHistory).map { $0 }
    }

    private func callGemini() async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let contents: [[String: Any]] = contextWindow().map {
            ["role": $0.role == "assistant" ? "model" : "user", "parts": [["text": $0.content]]]
        }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPromptText]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": 200, "temperature": 0.7]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        return parts?.first?["text"] as? String ?? "I'm not sure what to say. Try again!"
    }
}
