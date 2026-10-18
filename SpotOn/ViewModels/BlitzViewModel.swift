import Foundation
import Combine
import SwiftUI

@MainActor
class BlitzViewModel: ObservableObject {
    @Published var questions: [BlitzQuestion] = []
    @Published var currentIndex = 0
    @Published var score = 0
    @Published var timeLeft: Double = 60
    @Published var phase: Phase = .idle
    @Published var cardOffset: CGSize = .zero

    private var timer: AnyCancellable?
    /// Bumped on every start so a delayed swipe from a previous round
    /// can't advance the new one.
    private var round = 0
    private var isAdvancing = false

    enum Phase { case idle, running, finished }

    var currentQuestion: BlitzQuestion? { questions[safe: currentIndex] }
    var progress: Double { max(0, timeLeft / 60) }

    /// Rounds need at least two words that have something to answer with.
    static func canPlay(with words: [Word]) -> Bool { BlitzQuestion.playable(words).count >= 2 }

    func start(with words: [Word]) {
        let pool = BlitzQuestion.playable(words)
        guard pool.count >= 2 else { phase = .finished; return }
        round += 1
        isAdvancing = false
        cardOffset = .zero
        questions = pool.shuffled().prefix(10).map { BlitzQuestion.make(from: $0, allWords: pool) }
        currentIndex = 0
        score = 0
        timeLeft = 60
        phase = .running
        startTimer()
    }

    func answer(index: Int) {
        guard phase == .running, !isAdvancing, let q = currentQuestion else { return }
        if index == q.correctIndex { score += 1; SoundService.playCorrect() } else { SoundService.playWrong() }
        advance()
    }

    func swipe(knew: Bool) {
        guard phase == .running, !isAdvancing else { return }
        isAdvancing = true
        if knew { score += 1; SoundService.playCorrect() } else { SoundService.playWrong() }
        withAnimation(.spring()) { cardOffset = CGSize(width: knew ? 400 : -400, height: 0) }
        let thisRound = round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.round == thisRound else { return }
            self.cardOffset = .zero
            self.isAdvancing = false
            self.advance()
        }
    }

    func stop() { timer?.cancel(); timer = nil; phase = .finished }

    private func advance() {
        if currentIndex < questions.count - 1 { currentIndex += 1 } else { stop() }
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, self.phase == .running else { return }
                self.timeLeft -= 0.1
                if self.timeLeft <= 0 { self.stop() }
            }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
