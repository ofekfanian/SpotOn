import SwiftUI

struct WordBankView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.colorScheme) private var scheme
    @State private var selectedWord: Word?

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search words...", text: $wordBankVM.searchText)
                }
                .padding(10).background(.ultraThinMaterial).cornerRadius(12)
                .padding(.horizontal).padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(WordBankViewModel.StatusFilter.allCases, id: \.self) { status in
                            TagChipFilter(tag: status.rawValue, isSelected: wordBankVM.statusFilter == status) {
                                wordBankVM.statusFilter = status
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)

                if wordBankVM.filtered.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        wordBankVM.searchText.isEmpty ? "No words yet" : "No results",
                        systemImage: "book.closed",
                        description: Text(wordBankVM.searchText.isEmpty ? "Tap + to add your first word" : "Try a different search"))
                    Spacer()
                } else {
                    List {
                        ForEach(wordBankVM.paginated) { word in
                            WordRowView(word: word)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedWord = word }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        guard let uid = authVM.user?.uid else { return }
                                        Task { await wordBankVM.deleteWord(word, uid: uid) }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { wordBankVM.speak(word.word) } label: { Label("Speak", systemImage: "speaker.wave.2.fill") }
                                        .tint(.crystalMint)
                                }
                                .listRowBackground(Color.clear)
                                .onAppear {
                                    if word.id == wordBankVM.paginated.last?.id { wordBankVM.loadNextPage() }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            }
            .navigationTitle("My Word Bank")
            .sheet(item: $selectedWord) { word in
                WordDetailView(word: word).environmentObject(authVM).environmentObject(wordBankVM)
            }
            .applyTabBarVisibility()
        }
    }
}

struct WordRowView: View {
    let word: Word
    @AppStorage("targetLanguage") private var targetLang = "en"
    @AppStorage("nativeLanguage") private var nativeLang = "he"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(word.text(for: targetLang)).font(.headline)
                let help = word.text(for: nativeLang)
                if !help.isEmpty { Text(help).font(.subheadline).foregroundColor(.crystalMint) }
                Spacer()
                if word.isMastered { Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.caption) }
                if word.needsReview { Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.orange).font(.caption) }
            }
            Text(word.definition).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
            if !word.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(word.tags, id: \.self) { tag in
                        Text(tag).font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.crystalBlue.opacity(0.15)).foregroundColor(.crystalBlue).cornerRadius(6)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TagChipFilter: View {
    let tag: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(tag).font(.caption.bold())
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.crystalBlue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary).cornerRadius(20)
        }
    }
}

#Preview("Light") { MainTabView(initialTab: 1).environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { MainTabView(initialTab: 1).environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
