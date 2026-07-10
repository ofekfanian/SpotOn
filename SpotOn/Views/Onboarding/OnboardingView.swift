import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private enum Step { case level, test, result }
    @State private var step: Step = .level

    @State private var selfLevel: String? = nil
    @State private var isFinishing = false

    @State private var questions: [PlacementQuestion] = []
    @State private var qIndex = 0
    @State private var selectedOption: Int? = nil
    @State private var correctByLevel: [String: Int] = [:]
    @State private var recommendedLevel = "intermediate"

    private let levels: [(String, String, Color, String, String)] = [
        ("beginner", "leaf.fill", .crystalMint, "Beginner", "Basic everyday words"),
        ("intermediate", "flame.fill", .crystalBlue, "Intermediate", "Conversations & idioms"),
        ("advanced", "bolt.fill", .crystalGold, "Advanced", "Nuance, slang & business"),
    ]

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea()
            VStack(spacing: 24) {
                progressDots
                switch step {
                case .level: levelStep
                case .test: testStep
                case .result: resultStep
                }
            }
            .padding().frame(maxWidth: 520)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .animation(.easeInOut(duration: 0.25), value: qIndex)
    }

    private var progressDots: some View {
        let steps: [Step] = [.level, .test, .result]
        let current = steps.firstIndex(of: step) ?? 0
        return HStack {
            if current > 0 {
                Button(action: goBack) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3).foregroundStyle(LinearGradient.crystalShort)
                }
            } else {
                Image(systemName: "chevron.left.circle.fill").font(.title3).opacity(0)
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule().fill(i <= current ? AnyShapeStyle(LinearGradient.crystal) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                        .frame(width: i == current ? 26 : 10, height: 6)
                }
            }
            Spacer()
            Image(systemName: "chevron.left.circle.fill").font(.title3).opacity(0)
        }
        .padding(.horizontal, 4).padding(.top, 12)
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch step {
            case .test:   step = .level; qIndex = 0; selectedOption = nil
            case .result: step = selfLevel != nil ? .level : .test
            default: break
            }
        }
    }

    private var levelStep: some View {
        VStack(spacing: 28) {
            Spacer()
            header(title: "What's your level?", subtitle: "Your honest guess. The quick test will confirm it.")
            VStack(spacing: 14) {
                ForEach(levels, id: \.0) { id, icon, color, title, sub in
                    SelectRow(icon: icon, iconColor: color, title: title, subtitle: sub, isSelected: selfLevel == id) {
                        withAnimation(.spring(duration: 0.25)) { selfLevel = id }
                    }
                }
            }
            primaryButton("Take the quick test", enabled: selfLevel != nil) { startTest() }
            Button("Skip test, use my choice") { recommendedLevel = selfLevel ?? "intermediate"; step = .result }
                .font(.footnote).foregroundStyle(LinearGradient.crystalShort)
                .opacity(selfLevel == nil ? 0.4 : 1).disabled(selfLevel == nil)
            Spacer()
        }
    }

    private var testStep: some View {
        VStack(spacing: 24) {
            Spacer()
            if let q = questions[safe: qIndex] {
                Text("Quick Test  \(qIndex + 1)/\(questions.count)").font(.caption.bold()).foregroundColor(.secondary)
                Text("What does this mean?").font(.headline)
                Text(q.word).font(.system(size: 34, weight: .bold)).foregroundStyle(LinearGradient.crystal)
                VStack(spacing: 12) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                        Button { answer(idx, q: q) } label: {
                            ZStack {
                                Text(option).font(.body.bold()).multilineTextAlignment(.center)
                                HStack {
                                    Spacer()
                                    if selectedOption != nil && idx == q.correct { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                                    else if selectedOption == idx { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
                                }
                            }
                            .padding().frame(maxWidth: .infinity).background(optionColor(idx, q: q)).foregroundColor(.primary).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.crystalBlue.opacity(0.2), lineWidth: 1))
                        }
                        .disabled(selectedOption != nil)
                    }
                }
            }
            Spacer()
        }
    }

    private var resultStep: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 72)).foregroundStyle(LinearGradient.crystal)
            CrystalText(text: "You're all set!", font: .title.bold())
            VStack(spacing: 6) {
                Text("Recommended level").font(.subheadline).foregroundColor(.secondary)
                Text(recommendedLevel.capitalized).font(.system(size: 30, weight: .bold)).foregroundStyle(LinearGradient.crystalShort)
            }
            .padding(22).frame(maxWidth: .infinity).background(.ultraThinMaterial).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1))
            primaryButton(isFinishing ? "" : "Start Learning", enabled: !isFinishing) { finish() }
                .overlay { if isFinishing { ProgressView().tint(.white) } }
            Spacer()
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            SpotOnLogoView(height: 52)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(subtitle).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 54)
                .background(enabled ? AnyShapeStyle(LinearGradient.crystal) : AnyShapeStyle(Color.secondary.opacity(0.25))).cornerRadius(16)
        }
        .disabled(!enabled)
    }

    private func startTest() {
        correctByLevel = [:]; qIndex = 0; selectedOption = nil
        questions = buildQuestions()
        if questions.isEmpty { recommendedLevel = selfLevel ?? "intermediate"; step = .result } else { step = .test }
    }

    private func buildQuestions() -> [PlacementQuestion] {
        var result: [PlacementQuestion] = []
        for level in ["beginner", "intermediate", "advanced"] {
            let pool = VocabularyService.shared.words(for: level)
            guard pool.count >= 4 else { continue }
            for word in pool.shuffled().prefix(2) {
                let correct = hebrewTranslation(word)
                var distractors = pool.filter { $0.word != word.word }.shuffled().prefix(3).map { hebrewTranslation($0) }
                distractors.append(correct)
                let options = distractors.shuffled()
                let correctIdx = options.firstIndex(of: correct) ?? 0
                result.append(PlacementQuestion(word: word.word, options: options, correct: correctIdx, level: level))
            }
        }
        return result
    }

    private func hebrewTranslation(_ word: Word) -> String {
        word.translation.isEmpty ? word.word : word.translation
    }

    private func answer(_ idx: Int, q: PlacementQuestion) {
        guard selectedOption == nil else { return }
        selectedOption = idx
        if idx == q.correct { correctByLevel[q.level, default: 0] += 1; SoundService.playCorrect() } else { SoundService.playWrong() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if qIndex < questions.count - 1 { qIndex += 1; selectedOption = nil }
            else { computeLevel(); step = .result }
        }
    }

    private func computeLevel() {
        let total = correctByLevel.values.reduce(0, +)
        let adv = correctByLevel["advanced"] ?? 0
        if total <= 2 { recommendedLevel = "beginner" }
        else if adv >= 1 && total >= 5 { recommendedLevel = "advanced" }
        else { recommendedLevel = "intermediate" }
    }

    private func optionColor(_ idx: Int, q: PlacementQuestion) -> Color {
        guard selectedOption != nil else { return Color(.secondarySystemBackground) }
        if idx == q.correct { return Color.green.opacity(0.18) }
        if idx == selectedOption { return Color.red.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }

    private func finish() {
        isFinishing = true
        Task {
            await authVM.completeOnboarding(level: recommendedLevel)
            _ = await NotificationService.requestPermission()
            NotificationService.scheduleDailyReminder()
            isFinishing = false
            dismiss()   // no-op on first launch; closes the sheet when retaking from Settings
        }
    }
}

private struct PlacementQuestion { let word: String; let options: [String]; let correct: Int; let level: String }

private struct SelectRow: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title3).foregroundColor(iconColor)
                    .frame(width: 44, height: 44).background(iconColor.opacity(0.15)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                        .foregroundStyle(isSelected ? AnyShapeStyle(LinearGradient.crystal) : AnyShapeStyle(Color.primary))
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(LinearGradient.crystal).font(.title2) }
            }
            .padding().background(.ultraThinMaterial).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? AnyShapeStyle(LinearGradient.crystal) : AnyShapeStyle(Color.clear), lineWidth: 1.5))
        }
    }
}

#Preview("Light") { OnboardingView().environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { OnboardingView().environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
