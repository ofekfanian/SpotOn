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

    enum Phase { case idle, running, finished }

    var currentQuestion: BlitzQuestion? { questions[safe: currentIndex] }
    var progress: Double { max(0, timeLeft / 60) }

    func start(with words: [Word]) {
        guard words.count >= 2 else { return }
        questions = words.shuffled().prefix(10).map { BlitzQuestion.make(from: $0, allWords: words) }
        currentIndex = 0
        score = 0
        timeLeft = 60
        phase = .running
        startTimer()
    }

    func answer(index: Int) {
        guard phase == .running, let q = currentQuestion else { return }
        if index == q.correctIndex { score += 1 }
        advance()
    }

    func swipe(knew: Bool) {
        guard phase == .running else { return }
        if knew { score += 1 }
        withAnimation(.spring()) { cardOffset = CGSize(width: knew ? 400 : -400, height: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.cardOffset = .zero
            self.advance()
        }
    }

    func stop() { timer?.cancel(); phase = .finished }

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
