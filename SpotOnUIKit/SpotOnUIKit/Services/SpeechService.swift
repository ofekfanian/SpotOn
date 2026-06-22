import AVFoundation

// MARK: SpeechService
// Shared text-to-speech for reading words aloud in the right language.
class SpeechService {
    static let shared = SpeechService()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, language: String = "en-US") {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.45
        synth.speak(utterance)
    }
}
