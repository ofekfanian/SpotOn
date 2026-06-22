import UIKit

// MARK: WordCell
class WordCell: UICollectionViewCell {
    static let reuseID = "WordCell"

    private let wordLabel = UILabel()
    private let hebrewLabel = UILabel()
    private let frenchLabel = UILabel()
    private let levelLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.roundedGlass()

        wordLabel.font = .boldSystemFont(ofSize: 20)
        wordLabel.textColor = .crystalBlue
        hebrewLabel.font = .systemFont(ofSize: 16)
        hebrewLabel.textColor = .crystalMint
        hebrewLabel.textAlignment = .right
        frenchLabel.font = .systemFont(ofSize: 16)
        frenchLabel.textColor = .crystalGold
        levelLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        levelLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [wordLabel, hebrewLabel, frenchLabel, levelLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(_ word: Word) {
        // Show only the target language + the user's native translation.
        wordLabel.text = word.learnText
        hebrewLabel.text = word.helpText
        hebrewLabel.textAlignment = AppSettings.nativeLanguage == "he" ? .right : .left
        frenchLabel.isHidden = true
        levelLabel.text = word.level?.uppercased()
    }
}
