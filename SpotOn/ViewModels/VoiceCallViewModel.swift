import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
final class VoiceCallViewModel: ObservableObject {
    enum Phase { case idle, listening, thinking, speaking }

    @Published var phase: Phase = .idle
    @Published var liveTranscript = ""
    @Published var lastUserText = ""
    @Published var lastTutorText = ""
    @Published var errorMessage: String?
    @Published var handsFree = true

    private let recognizer = SpeechRecognizer()
    private var cancellables = Set<AnyCancellable>()
    private var isCallActive = false
    private let silencePause = 1.8

    private let apiKey = Secrets.geminiAPIKey
    private let model = "gemini-1.5-flash"
    private let maxHistory = 10
    private var history: [ChatMessage] = []

    private let systemPromptText = """
        You are a friendly English conversation tutor on a phone call in an app named SpotOn. \
        Keep every reply very short and natural — one or two spoken sentences, no lists, no markdown. \
        Gently correct major mistakes in one short clause, then ask a simple follow-up question.
        """

    init() {
        recognizer.$transcript.receive(on: RunLoop.main)
            .assign(to: \.liveTranscript, on: self).store(in: &cancellables)
        recognizer.$transcript
            .debounce(for: .seconds(silencePause), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self, self.phase == .listening,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { await self.stopAndSend() }
            }.store(in: &cancellables)
    }

    func beginCall() async -> Bool {
        let ok = await recognizer.requestAuthorization()
        guard ok else { return false }
        isCallActive = true
        startListening()
        return true
    }

    func startListening() {
        guard isCallActive, phase == .idle || phase == .speaking else { return }
        errorMessage = nil; liveTranscript = ""
        SpeechService.shared.stop()
        do { try recognizer.startTranscribing(); phase = .listening; haptic(.light) }
        catch { errorMessage = "Couldn't access the microphone."; phase = .idle }
    }

    func micTapped() async {
        switch phase {
        case .listening: await stopAndSend()
        case .thinking: break
        case .idle, .speaking:
            SpeechService.shared.stop(); phase = .idle; startListening()
        }
    }

    func stopAndSend() async {
        guard phase == .listening else { return }
        recognizer.stopTranscribing()
        let text = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { phase = .idle; return }
        lastUserText = text
        history.append(ChatMessage(role: "user", content: text))
        phase = .thinking
        haptic(.medium)
        do {
            let reply = try await callGemini()
            lastTutorText = reply
            history.append(ChatMessage(role: "assistant", content: reply))
            phase = .speaking
            SpeechService.shared.onFinish = { [weak self] in
                Task { @MainActor in
                    guard let self, self.phase == .speaking else { return }
                    self.phase = .idle
                    if self.handsFree && self.isCallActive { self.startListening() }
                }
            }
            SpeechService.shared.speak(reply, accent: "en-US")
        } catch {
            errorMessage = "Could not reach the tutor. Check your connection."
            phase = .idle
        }
    }

    func endCall() {
        isCallActive = false
        recognizer.stopTranscribing()
        SpeechService.shared.onFinish = nil
        SpeechService.shared.stop()
        phase = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func callGemini() async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let contents: [[String: Any]] = history.suffix(maxHistory).map {
            ["role": $0.role == "assistant" ? "model" : "user", "parts": [["text": $0.content]]]
        }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPromptText]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": 120, "temperature": 0.7]
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
        return parts?.first?["text"] as? String ?? "Sorry, could you say that again?"
    }
}
