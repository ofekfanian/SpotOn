import AVFoundation

final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()
    @Published private(set) var isSpeaking = false
    var onFinish: (() -> Void)?
    private let synth = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, accent: String = "en-US") {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        utterance.rate = 0.45
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { isSpeaking = true }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        isSpeaking = false
        onFinish?()
    }
}
