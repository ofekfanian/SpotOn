import UIKit

// MARK: WordDetailController
class WordDetailController: UIViewController {

    private let word: Word

    init(word: Word) {
        self.word = word
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = word.learnText
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let nativeName = Language(rawValue: AppSettings.nativeLanguage)?.name ?? "Translation"
        let title = label(word.learnText, font: .boldSystemFont(ofSize: 34), color: .crystalBlue)
        let translation = row(nativeName, word.helpText, color: .crystalMint)
        let level = row("Level", word.level, color: .secondaryLabel)

        let stack = UIStackView(arrangedSubviews: [title, translation, level])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func row(_ caption: String, _ value: String?, color: UIColor) -> UIView {
        let c = label(caption.uppercased(), font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabel)
        let v = label(value ?? "—", font: .systemFont(ofSize: 22, weight: .medium), color: color)
        let stack = UIStackView(arrangedSubviews: [c, v])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    private func label(_ text: String?, font: UIFont, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.numberOfLines = 0
        return l
    }
}
