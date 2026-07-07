import SwiftUI

struct BlitzLaunchView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme
    @State private var showBlitz = false
    @State private var pulse = false

    private var canPlay: Bool { wordBankVM.words.count >= 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Hero — animated countdown circle
                    ZStack {
                        Circle()
                            .stroke(LinearGradient.crystal, lineWidth: 3)
                            .frame(width: 160, height: 160)
                            .scaleEffect(pulse ? 1.12 : 1.0)
                            .opacity(pulse ? 0 : 0.6)
                            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)

                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 140, height: 140)
                            .overlay(Circle().strokeBorder(LinearGradient.crystal, lineWidth: 1.5))
                            .shadow(color: Color.crystalBlue.opacity(0.35), radius: 24)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("60")
                                .font(.system(size: 58, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient.crystal)
                            Text("s")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.crystalMint)
                        }
                    }
                    .onAppear { pulse = true }

                    Spacer().frame(height: 36)

                    // Title + subtitle
                    VStack(spacing: 10) {
                        CrystalText(text: "Blitz", font: .system(size: 36, weight: .black, design: .rounded))
                        Text("Race through your words in 60 seconds.\nSwipe, tap and conquer.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    Spacer().frame(height: 32)

                    // Stats row
                    HStack(spacing: 24) {
                        statPill(icon: "books.vertical.fill", value: "\(wordBankVM.words.count)", label: "words")
                        statPill(icon: "clock.fill", value: "60", label: "seconds")
                        statPill(icon: "star.fill", value: "×5", label: "XP/word")
                    }

                    Spacer().frame(height: 40)

                    // Start button
                    VStack(spacing: 10) {
                        Button { showBlitz = true } label: {
                            Text("Start")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(canPlay ? AnyView(LinearGradient.crystal) : AnyView(Color.secondary.opacity(0.3)))
                                .cornerRadius(18)
                                .shadow(color: canPlay ? Color.crystalBlue.opacity(0.4) : .clear, radius: 14, y: 6)
                        }
                        .disabled(!canPlay)
                        .padding(.horizontal, 32)

                        if !canPlay {
                            Text("Add at least 2 words to play")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    CrystalText(text: "Blitz", font: .headline)
                }
            }
            .fullScreenCover(isPresented: $showBlitz) {
                BlitzView(words: wordBankVM.words).environmentObject(authVM)
            }
            .applyTabBarVisibility()
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(LinearGradient.crystalShort)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient.crystalShort)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(LinearGradient.crystal.opacity(0.25), lineWidth: 1))
    }
}

struct BlitzView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let words: [Word]
    @StateObject private var vm = BlitzViewModel()

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea()
            switch vm.phase {
            case .idle:
                Color.clear.onAppear { vm.start(with: words) }
            case .running:
                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal).padding(.top, 8)
                    TimerBarView(progress: vm.progress, timeLeft: vm.timeLeft).padding()
                    HStack {
                        Text("Score: \(vm.score)").font(.headline).foregroundStyle(LinearGradient.crystalShort)
                        Spacer()
                        Text("\(vm.currentIndex + 1) / \(vm.questions.count)").foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    Spacer()
                    if let q = vm.currentQuestion {
                        QuestionCard(question: q, vm: vm)
                            .offset(vm.cardOffset)
                            .animation(.interactiveSpring(), value: vm.cardOffset).padding()
                    }
                    Spacer()
                }
            case .finished:
                ResultView(score: vm.score, total: vm.questions.count) {
                    dismiss()
                } onRetry: { vm.start(with: words) }
                // Award XP when the round ends — not on "Done" — so replays don't lose earned XP.
                .onAppear {
                    if let uid = authVM.user?.uid, vm.score > 0 {
                        Task { try? await RealtimeDatabaseService.shared.addXP(vm.score * 5, for: uid) }
                    }
                }
            }
        }
    }
}

private struct TimerBarView: View {
    let progress: Double; let timeLeft: Double
    private var barColor: AnyShapeStyle {
        if progress > 0.5 { return AnyShapeStyle(LinearGradient.crystalShort) }
        if progress > 0.25 { return AnyShapeStyle(Color.orange) }
        return AnyShapeStyle(Color.red)
    }
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 8).fill(barColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 12)
            Text("\(Int(ceil(timeLeft)))s").font(.caption.bold())
                .foregroundColor(progress > 0.5 ? .crystalBlue : progress > 0.25 ? .orange : .red)
        }
    }
}

private struct QuestionCard: View {
    let question: BlitzQuestion
    @ObservedObject var vm: BlitzViewModel
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(LinearGradient.crystal).frame(height: 140)
                    .shadow(color: Color.crystalBlue.opacity(0.3), radius: 12, y: 6)
                VStack(spacing: 8) {
                    Text(question.word.word).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                    if !question.word.context.isEmpty {
                        Text(question.word.context).font(.caption).foregroundColor(.white.opacity(0.85)).italic()
                    }
                }
            }
            .gesture(DragGesture()
                .onChanged { vm.cardOffset = CGSize(width: $0.translation.width, height: 0) }
                .onEnded { g in
                    if g.translation.width > 100 { vm.swipe(knew: true) }
                    else if g.translation.width < -100 { vm.swipe(knew: false) }
                    else { withAnimation { vm.cardOffset = .zero } }
                })
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { idx, option in
                    Button { vm.answer(index: idx) } label: {
                        Text(option).font(.subheadline).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading).padding()
                            .background(.ultraThinMaterial).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.crystalBlue.opacity(0.2), lineWidth: 1))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

private struct ResultView: View {
    let score: Int; let total: Int; let onDone: () -> Void; let onRetry: () -> Void
    private var pct: Int { total > 0 ? Int(Double(score) / Double(total) * 100) : 0 }
    private var resultIcon: String { pct >= 80 ? "trophy.fill" : pct >= 50 ? "hand.thumbsup.fill" : "book.fill" }
    private var resultColor: Color { pct >= 80 ? .crystalGold : pct >= 50 ? .crystalBlue : .crystalMint }
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: resultIcon).font(.system(size: 72)).foregroundColor(resultColor)
            VStack(spacing: 8) {
                CrystalText(text: "Blitz Complete!", font: .largeTitle.bold())
                Text("\(score) / \(total) correct  •  +\(score * 5) XP").font(.title3).foregroundColor(.secondary)
            }
            CircleProgress(percent: pct)
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Text("Play Again").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52).background(LinearGradient.crystal).cornerRadius(16)
                        .shadow(color: Color.crystalBlue.opacity(0.3), radius: 8, y: 4)
                }
                Button(action: onDone) {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                        .background(.ultraThinMaterial).cornerRadius(16)
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }
}

private struct CircleProgress: View {
    let percent: Int
    var body: some View {
        ZStack {
            Circle().stroke(Color(.systemGray5), lineWidth: 12).frame(width: 120, height: 120)
            Circle().trim(from: 0, to: Double(percent) / 100)
                .stroke(LinearGradient.crystal, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 120, height: 120).rotationEffect(.degrees(-90))
                .animation(.spring(), value: percent)
            CrystalText(text: "\(percent)%", font: .title2.bold())
        }
    }
}

#Preview("Light") { MainTabView(initialTab: 3).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 3).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
