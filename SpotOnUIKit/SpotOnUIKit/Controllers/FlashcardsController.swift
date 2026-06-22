import UIKit

// MARK: FlashcardsController
// Glass card: double-tap to flip (EN ↔ HE/FR), swipe to advance.
class FlashcardsController: UIViewController {

    private let deck: [Word]
    private var index = 0
    private var showingBack = false

    private let card = UIView()
    private let frontLabel = UILabel()
    private let backLabel = UILabel()
    private let progressLabel = UILabel()
    private let speakButton = UIButton(type: .system)

    init(level: String) {
        self.deck = Array(VocabularyService.shared.words(for: level).shuffled().prefix(20))
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Flashcards"
        setupUI()
        render()
    }

    private func setupUI() {
        progressLabel.font = .boldSystemFont(ofSize: 16)
        progressLabel.textColor = .crystalBlue
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressLabel)

        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 24
        card.layer.borderWidth = 2
        card.layer.borderColor = UIColor.crystalBlue.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        frontLabel.font = .boldSystemFont(ofSize: 32)
        frontLabel.textColor = .crystalBlue
        frontLabel.textAlignment = .center
        frontLabel.numberOfLines = 0
        backLabel.font = .boldSystemFont(ofSize: 24)
        backLabel.textColor = .crystalMint
        backLabel.textAlignment = .center
        backLabel.numberOfLines = 0
        backLabel.isHidden = true

        for l in [frontLabel, backLabel] {
            l.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(l)
            NSLayoutConstraint.activate([
                l.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                l.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                l.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                l.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
            ])
        }

        speakButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        speakButton.tintColor = .crystalBlue
        speakButton.addTarget(self, action: #selector(speakTapped), for: .touchUpInside)
        speakButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speakButton)

        let hint = UILabel()
        hint.text = "Double-tap to flip · Swipe to continue"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabel
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            card.heightAnchor.constraint(equalToConstant: 300),

            speakButton.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 16),
            speakButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        card.addGestureRecognizer({
            let t = UITapGestureRecognizer(target: self, action: #selector(flip))
            t.numberOfTapsRequired = 2
            return t
        }())
        for dir: UISwipeGestureRecognizer.Direction in [.left, .right] {
            let s = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            s.direction = dir
            card.addGestureRecognizer(s)
        }
    }

    private func render() {
        guard index < deck.count else { finish(); return }
        let word = deck[index]
        frontLabel.text = word.learnText
        backLabel.text = word.helpText
        showingBack = false
        frontLabel.isHidden = false
        backLabel.isHidden = true
        progressLabel.text = "\(index + 1) / \(deck.count)"
    }

    @objc private func flip() {
        showingBack.toggle()
        UIView.transition(with: card, duration: 0.4, options: .transitionFlipFromRight) {
            self.frontLabel.isHidden = self.showingBack
            self.backLabel.isHidden = !self.showingBack
        }
    }

    @objc private func swiped(_ g: UISwipeGestureRecognizer) {
        let off: CGFloat = g.direction == .right ? 600 : -600
        UIView.animate(withDuration: 0.25, animations: {
            self.card.transform = CGAffineTransform(translationX: off, y: 0)
        }) { _ in
            self.card.transform = .identity
            self.index += 1
            self.render()
        }
    }

    @objc private func speakTapped() {
        guard index < deck.count else { return }
        let code = Language(rawValue: AppSettings.targetLanguage)?.speechCode ?? "en-US"
        SpeechService.shared.speak(deck[index].learnText, language: code)
    }

    private func finish() {
        let alert = UIAlertController(title: "All done!", message: "You finished the deck.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
