import SwiftData
import Foundation

/// Seeds passages.json into the SwiftData store once per content version.
/// Bump `seededKey` whenever passages are added: existing installs then pick
/// up the new ones (passages already stored are skipped by id, keeping progress).
@MainActor
final class PassageSeeder {
    static let shared = PassageSeeder()
    private let seededKey = "passagesSeeded_v2"

    private init() {}

    func seedIfNeeded(in context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        await seed(in: context)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    // MARK: - Private

    private func seed(in context: ModelContext) async {
        guard let url = Bundle.main.url(forResource: "passages", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[PassageSeeder] passages.json not found in bundle, skipping")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(SeedFile.self, from: data)
            var inserted = 0

            for entry in decoded.passages {
                // Copy to a local let — SwiftData #Predicate can't capture loop-variable properties directly
                let entryId = entry.id
                let existing = try? context.fetch(
                    FetchDescriptor<ReadingPassage>(
                        predicate: #Predicate { $0.id == entryId }
                    )
                )
                guard existing?.isEmpty ?? true else { continue }

                let passage = ReadingPassage(
                    id: entry.id,
                    title: entry.title,
                    passageDescription: entry.description,
                    content: entry.content,
                    level: entry.level,
                    orderIndex: entry.orderIndex
                )
                context.insert(passage)

                for wEntry in entry.targetWords {
                    let pw = PassageWord(
                        text: wEntry.text,
                        definition: wEntry.definition,
                        hebrewTranslation: wEntry.hebrew
                    )
                    pw.passage = passage
                    passage.words.append(pw)
                    context.insert(pw)
                }

                inserted += 1
            }

            try context.save()
            print("[PassageSeeder] Seeded \(inserted) passages")
        } catch {
            print("[PassageSeeder] Seed failed: \(error)")
        }
    }

    // MARK: - Decodable helpers

    private struct SeedFile: Decodable {
        let passages: [SeedPassage]
    }

    private struct SeedPassage: Decodable {
        let id: String
        let title: String
        let description: String
        let level: Int
        let orderIndex: Int
        let content: String
        let targetWords: [SeedWord]
    }

    private struct SeedWord: Decodable {
        let text: String
        let definition: String
        let hebrew: String
    }
}
