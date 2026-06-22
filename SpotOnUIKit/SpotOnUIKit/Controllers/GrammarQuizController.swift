import UIKit

// MARK: GrammarQuizController
// Reusable drill for connectors/tenses: pick the missing word, then see an
// explanation + Hebrew translation.
class GrammarQuizController: UIViewController {

    private let deck: [GrammarService.Item]
    private var index = 0
    private var score = 0
    private var answered = false

    private let progressLabel = UILabel()
    private let sentenceLabel = UILabel()
    private let explanationLabel = UILabel()
    private var optionButtons: [UIButton] = []
    private let nextButton = UIButton(type: .system)

    init(topic: String, title: String) {
        self.deck = GrammarService.shared.items(for: topic).shuffled()
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        render()
    }

    private func setupUI() {
        progressLabel.font = .boldSystemFont(ofSize: 16)
        progressLabel.textColor = .crystalBlue
        progressLabel.textAlignment = .center

        sentenceLabel.font = .boldSystemFont(ofSize: 24)
        sentenceLabel.numberOfLines = 0
        sentenceLabel.textAlignment = .center

        explanationLabel.font = .systemFont(ofSize: 15)
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.numberOfLines = 0
        explanationLabel.textAlignment = .center

        let optionsStack = UIStackView()
        optionsStack.axis = .vertical
        optionsStack.spacing = 10
        for i in 0..<4 {
            let b = UIButton(type: .system)
            b.titleLabel?.font = .boldSystemFont(ofSize: 18)
            b.backgroundColor = .secondarySystemBackground
            b.setTitleColor(.label, for: .normal)
            b.layer.cornerRadius = 14
            b.heightAnchor.constraint(equalToConstant: 54).isActive = true
            b.tag = i
            b.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
            optionButtons.append(b)
            optionsStack.addArrangedSubview(b)
        }

        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        nextButton.tintColor = .white
        nextButton.backgroundColor = .crystalBlue
        nextButton.layer.cornerRadius = 14
        nextButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        nextButton.isHidden = true
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [progressLabel, sentenceLabel, optionsStack, explanationLabel, nextButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func render() {
        guard index < deck.count else { finish(); return }
        answered = false
        let item = deck[index]
        sentenceLabel.text = item.sentence.replacingOccurrences(of: "___", with: "_____")
        explanationLabel.text = nil
        nextButton.isHidden = true
        progressLabel.text = "\(index + 1) / \(deck.count)   ·   Score \(score)"
        let shuffled = item.options.shuffled()
        for (i, b) in optionButtons.enumerated() {
            b.setTitle(i < shuffled.count ? shuffled[i] : "—", for: .normal)
            b.backgroundColor = .secondarySystemBackground
            b.isEnabled = true
        }
    }

    @objc private func optionTapped(_ sender: UIButton) {
        guard !answered, index < deck.count else { return }
        answered = true
        let item = deck[index]
        if sender.title(for: .normal) == item.answer { score += 1 }
        for b in optionButtons {
            b.isEnabled = false
            if b.title(for: .normal) == item.answer {
                b.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.25)
            } else if b == sender {
                b.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            }
        }
        sentenceLabel.text = item.sentence.replacingOccurrences(of: "___", with: item.answer)
        explanationLabel.text = "\(item.explanation)\n\(item.he)"
        nextButton.isHidden = false
    }

    @objc private func nextTapped() {
        index += 1
        render()
    }

    private func finish() {
        RealtimeDatabaseService.shared.addXP(score * 5)
        let alert = UIAlertController(title: "Done!",
                                     message: "Score: \(score) / \(deck.count)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
