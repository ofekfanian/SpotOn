import AudioToolbox

/// Plays short system feedback sounds for correct/incorrect answers.
/// Uses built-in iOS system sound IDs — no audio assets needed, and respects
/// the user's silent switch and volume automatically.
enum SoundService {
    private static let correctSoundID: SystemSoundID = 1057   // bright ascending "tock"
    private static let wrongSoundID: SystemSoundID = 1053     // low double "tap"

    static func playCorrect() {
        AudioServicesPlaySystemSound(correctSoundID)
    }

    static func playWrong() {
        AudioServicesPlaySystemSound(wrongSoundID)
    }
}
