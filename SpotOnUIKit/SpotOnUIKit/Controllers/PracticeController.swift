import UIKit

// MARK: PracticeController
// Hub that launches each game after picking a level.
class PracticeController: UIViewController {

    private let games: [(title: String, subtitle: String, icon: String, color: UIColor)] = [
        ("Flashcards", "Swipe & flip in 3 languages", "rectangle.on.rectangle.angled", .crystalMint),
        ("Sentence Completion", "Fill in the blanks", "text.append", .crystalBlue),
        ("60-Second Blitz", "Race the clock", "bolt.fill", .crystalGold),
        ("Describe the Image", "Say what you see, get corrected", "photo.fill", .crystalBlue),
        ("Small Words", "a / the / did / since / then...", "textformat.abc", .crystalGold),
        ("Tenses", "Past · Present · Future", "clock.arrow.circlepath", .crystalBlue),
    ]

    private let levels = ["beginner", "intermediate", "advanced"]

    // Games that need a level prompt before launching.
    private var needsLevel: Set<Int> { [0, 1, 2] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Practice"
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, game) in games.enumerated() {
            let card = gameCard(game, tag: index)
            stack.addArrangedSubview(card)
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func gameCard(_ game: (title: String, subtitle: String, icon: String, color: UIColor), tag: Int) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: game.icon))
        icon.tintColor = game.color
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true

        let title = UILabel()
        title.text = game.title
        title.font = .boldSystemFont(ofSize: 18)
        let sub = UILabel()
        sub.text = game.subtitle
        sub.font = .systemFont(ofSize: 13)
        sub.textColor = .secondaryLabel
        let texts = UIStackView(arrangedSubviews: [title, sub])
        texts.axis = .vertical
        texts.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, texts])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 18, left: 16, bottom: 18, right: 16)
        row.backgroundColor = .secondarySystemBackground
        row.roundedGlass()
        row.tag = tag
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        return row
    }

    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        if needsLevel.contains(tag) {
            pickLevel { [weak self] level in self?.launch(game: tag, level: level) }
        } else {
            launch(game: tag, level: "")
        }
    }

    private func pickLevel(_ completion: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: "Pick a level", message: nil, preferredStyle: .actionSheet)
        for level in levels {
            sheet.addAction(UIAlertAction(title: level.capitalized, style: .default) { _ in completion(level) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func launch(game: Int, level: String) {
        let vc: UIViewController
        switch game {
        case 0: vc = FlashcardsController(level: level)
        case 1: vc = SentenceController(level: level)
        case 2: vc = BlitzController(level: level)
        case 3: vc = DescribeImageController()
        case 4: vc = GrammarQuizController(topic: "connectors", title: "Small Words")
        default: vc = GrammarQuizController(topic: "tenses", title: "Tenses")
        }
        navigationController?.pushViewController(vc, animated: true)
    }
}
