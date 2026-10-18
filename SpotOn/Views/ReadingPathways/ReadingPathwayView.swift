import SwiftUI
import SwiftData

struct ReadingPathwayView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme)  private var scheme

    @StateObject private var vm = ReadingPathwayViewModel()

    private let levels = [(1, "Beginner", Color.crystalMint), (2, "Intermediate", Color.crystalBlue), (3, "Advanced", Color.crystalGold)]

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    progressHeader
                    ForEach(levels, id: \.0) { level, label, color in
                        let group = vm.passages.filter { $0.level == level }
                        if !group.isEmpty {
                            levelSection(level: level, label: label, color: color, passages: group)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(LinearGradient.crystalShort)
                    CrystalText(text: "Reading Pathways", font: .headline)
                }
            }
        }
        .onAppear { vm.loadPassages(context: ctx) }
        .applyTabBarVisibility()
    }

    // MARK: Progress header

    private var progressHeader: some View {
        let total     = vm.passages.count
        let done      = vm.passages.filter(\.isCompleted).count
        let pct       = total == 0 ? 0.0 : Double(done) / Double(total)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(LinearGradient.crystalShort, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: pct)
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Progress").font(.headline)
                Text("\(done) of \(total) passages completed")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(LinearGradient.crystal.opacity(0.25), lineWidth: 1))
    }

    // MARK: Level section

    private func levelSection(level: Int, label: String, color: Color, passages: [ReadingPassage]) -> some View {
        let done = passages.filter(\.isCompleted).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: levelIcon(level))
                        .font(.subheadline.bold())
                        .foregroundColor(color)
                    Text(label)
                        .font(.headline)
                }
                Spacer()
                Text("\(done)/\(passages.count)")
                    .font(.caption.bold()).foregroundColor(color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(color.opacity(0.12)).cornerRadius(8)
            }

            ForEach(Array(passages.enumerated()), id: \.element.id) { index, passage in
                let isLocked = isLocked(passage: passage, allInLevel: passages)
                NavigationLink {
                    ReadingDetailView(passage: passage)
                        .environmentObject(authVM)
                        .environmentObject(wordBankVM)
                        .environmentObject(vm)
                } label: {
                    PassageCard(passage: passage, color: color, isLocked: isLocked, index: index)
                }
                .disabled(isLocked)
                .buttonStyle(.plain)
            }
        }
    }

    private func isLocked(passage: ReadingPassage, allInLevel: [ReadingPassage]) -> Bool {
        guard passage.orderIndex > allInLevel.map(\.orderIndex).min() ?? 0 else { return false }
        let sorted = allInLevel.sorted { $0.orderIndex < $1.orderIndex }
        guard let pos = sorted.firstIndex(where: { $0.id == passage.id }), pos > 0 else { return false }
        return !sorted[pos - 1].isCompleted
    }

    private func levelIcon(_ level: Int) -> String {
        switch level {
        case 1: return "leaf.fill"
        case 2: return "flame.fill"
        case 3: return "bolt.fill"
        default: return "star.fill"
        }
    }

    private var background: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg)
            LinearGradient(colors: [Color.crystalBlue.opacity(0.06), Color.crystalMint.opacity(0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(.ultraThinMaterial).opacity(0.7)
            ScatteredLettersBackground().opacity(0.35)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Passage card

private struct PassageCard: View {
    let passage: ReadingPassage
    let color: Color
    let isLocked: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            // Connector dot
            ZStack {
                Circle()
                    .fill(passage.isCompleted ? color : (isLocked ? Color.secondary.opacity(0.2) : color.opacity(0.15)))
                    .frame(width: 40, height: 40)
                Image(systemName: passage.isCompleted ? "checkmark" : (isLocked ? "lock.fill" : "\(index + 1).circle"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(passage.isCompleted ? .white : (isLocked ? .secondary : color))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(passage.title).font(.subheadline.bold())
                        .foregroundColor(isLocked ? .secondary : .primary)
                    if passage.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption).foregroundColor(color)
                    }
                }
                Text(passage.passageDescription)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label("\(passage.words.count) words", systemImage: "textformat")
                    if passage.isCompleted, let d = passage.completedAt {
                        Label(d.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    }
                }
                .font(.caption2).foregroundColor(.secondary.opacity(0.7))
            }
            Spacer()
            if !isLocked {
                Image(systemName: "chevron.right")
                    .font(.caption.bold()).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    passage.isCompleted ? AnyShapeStyle(color.opacity(0.4)) : AnyShapeStyle(Color.clear),
                    lineWidth: 1.5
                )
        )
        .opacity(isLocked ? 0.55 : 1)
    }
}

#Preview("Light") { MainTabView(initialTab: 3).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 3).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
