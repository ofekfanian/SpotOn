import SwiftUI

// Loads sentences.json (by level) for the fill-in-the-blank game.
private final class SentenceBank {
    static let shared = SentenceBank()
    struct Item: Decodable { let sentence: String; let answer: String; let options: [String]; let he: String; let fr: String }
    private var byLevel: [String: [Item]] = [:]
    private var loaded = false
    private func loadIfNeeded() {
        guard !loaded else { return }; loaded = true
        guard let url = Bundle.main.url(forResource: "sentences", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Item]].self, from: data) else { return }
        byLevel = decoded
    }
    func sentences(for level: String) -> [Item] { loadIfNeeded(); return byLevel[level] ?? [] }
}

struct SentenceCompletionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let level: String

    @State private var deck: [SentenceBank.Item] = []
    @State private var index = 0
    @State private var score = 0
    @State private var selected: String?
    @State private var shuffledOptions: [String] = []
    @State private var finished = false

    private let sessionSize = 10
    private var current: SentenceBank.Item? { deck[safe: index] }
    private var answered: Bool { selected != nil }
    private var progress: Double { deck.isEmpty ? 0 : Double(index) / Double(deck.count) }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea()
            if finished { resultView.transition(.scale(scale: 0.9).combined(with: .opacity)) } else { playView }
        }
        .onAppear(perform: setup)
    }

    private var playView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary) }
                Spacer()
                Text("\(min(index + 1, deck.count)) / \(deck.count)").font(.headline).foregroundStyle(LinearGradient.crystalShort)
                Spacer()
                Text("Score \(score)").font(.subheadline.bold()).foregroundColor(.crystalMint)
            }
            .padding(.horizontal).padding(.top, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(LinearGradient.crystal).frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8).padding(.horizontal).padding(.top, 14)

            Spacer()

            if let item = current {
                VStack(spacing: 14) {
                    Image(systemName: "text.append").font(.title2).foregroundStyle(LinearGradient.crystalShort)
                    Text(displaySentence(item)).font(.title3.bold()).multilineTextAlignment(.center).foregroundColor(.primary)
                    if answered {
                        Divider().frame(width: 80)
                        Text(item.he).font(.subheadline).foregroundColor(.crystalMint).environment(\.layoutDirection, .rightToLeft)
                        Text(item.fr).font(.subheadline).foregroundColor(.crystalBlue)
                    }
                }
                .padding(22).frame(maxWidth: .infinity).background(.ultraThinMaterial).cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1.5))
                .padding(.horizontal)

                VStack(spacing: 10) {
                    ForEach(shuffledOptions, id: \.self) { option in
                        Button { answer(option, correct: item.answer) } label: {
                            HStack {
                                Text(option).font(.body.bold())
                                Spacer()
                                if answered && option == item.answer { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                                else if answered && option == selected { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
                            }
                            .padding().frame(maxWidth: .infinity).background(optionColor(option, answer: item.answer))
                            .foregroundColor(.primary).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(optionBorder(option, answer: item.answer), lineWidth: 1))
                        }
                        .disabled(answered)
                    }
                }
                .padding(.horizontal).padding(.top, 18)
            }

            Spacer()

            if answered {
                Button(action: next) {
                    Text(index < deck.count - 1 ? "Next" : "Finish").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52).background(LinearGradient.crystal).cornerRadius(16)
                }
                .padding(.horizontal).padding(.bottom, 28).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 72)).foregroundColor(.crystalMint)
            CrystalText(text: "Great Work!", font: .largeTitle.bold())
            Text("\(score) / \(deck.count) correct  •  +\(score * 5) XP").font(.title3).foregroundColor(.secondary)
            VStack(spacing: 12) {
                Button(action: setup) {
                    Text("Play Again").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 52)
                        .background(LinearGradient.crystal).cornerRadius(16)
                }
                Button { dismiss() } label: {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).frame(height: 52).background(.ultraThinMaterial).cornerRadius(16)
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func setup() {
        deck = Array(SentenceBank.shared.sentences(for: level).shuffled().prefix(sessionSize))
        index = 0; score = 0; selected = nil; finished = deck.isEmpty
        shuffledOptions = current?.options.shuffled() ?? []
    }
    private func displaySentence(_ item: SentenceBank.Item) -> String {
        item.sentence.replacingOccurrences(of: "___", with: answered ? (selected ?? "") : "_____")
    }
    private func answer(_ option: String, correct: String) {
        guard !answered else { return }
        selected = option
        if option == correct { score += 1 }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    private func next() {
        if index < deck.count - 1 { index += 1; selected = nil; shuffledOptions = current?.options.shuffled() ?? [] }
        else {
            if let uid = authVM.user?.uid { Task { try? await RealtimeDatabaseService.shared.addXP(score * 5, for: uid) } }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { finished = true }
        }
    }
    private func optionColor(_ option: String, answer: String) -> Color {
        guard answered else { return Color(.secondarySystemBackground) }
        if option == answer { return Color.green.opacity(0.18) }
        if option == selected { return Color.red.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }
    private func optionBorder(_ option: String, answer: String) -> Color {
        guard answered else { return Color.crystalBlue.opacity(0.2) }
        if option == answer { return .green }
        if option == selected { return .red }
        return .clear
    }
}
