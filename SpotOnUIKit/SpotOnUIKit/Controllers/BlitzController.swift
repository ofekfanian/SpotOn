import UIKit

// MARK: BlitzController
// 60-second multiple-choice race: pick the correct translation.
class BlitzController: UIViewController {

    private let pool: [Word]
    private var current: Word?
    private var score = 0
    private var timeLeft = 60
    private var timer: Timer?

    private let timeLabel = UILabel()
    private let scoreLabel = UILabel()
    private let wordLabel = UILabel()
    private var optionButtons: [UIButton] = []

    init(level: String) {
        let words = VocabularyService.shared.words(for: level)
        self.pool = words.count >= 4 ? words : VocabularyService.shared.allWords()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Blitz"
        setupUI()
        startTimer()
        nextQuestion()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }

    private func setupUI() {
        timeLabel.font = .boldSystemFont(ofSize: 40)
        timeLabel.textColor = .crystalBlue
        timeLabel.textAlignment = .center
        scoreLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        scoreLabel.textColor = .secondaryLabel
        scoreLabel.textAlignment = .center
        wordLabel.font = .boldSystemFont(ofSize: 34)
        wordLabel.textColor = .label
        wordLabel.textAlignment = .center
        wordLabel.numberOfLines = 0

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

        let stack = UIStackView(arrangedSubviews: [timeLabel, scoreLabel, wordLabel, optionsStack])
        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func startTimer() {
        timeLabel.text = "\(timeLeft)"
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.timeLeft -= 1
            self.timeLabel.text = "\(self.timeLeft)"
            self.timeLabel.textColor = self.timeLeft <= 10 ? .systemRed : .crystalBlue
            if self.timeLeft <= 0 { self.finish() }
        }
    }

    private func nextQuestion() {
        guard let answer = pool.randomElement() else { return }
        current = answer
        wordLabel.text = answer.word
        var options = pool.filter { $0.word != answer.word }.shuffled().prefix(3).compactMap { $0.hebrew }
        options.append(answer.hebrew ?? "")
        let shuffled = options.shuffled()
        for (i, b) in optionButtons.enumerated() {
            b.setTitle(i < shuffled.count ? shuffled[i] : "—", for: .normal)
            b.backgroundColor = .secondarySystemBackground
        }
        scoreLabel.text = "Score: \(score)"
    }

    @objc private func optionTapped(_ sender: UIButton) {
        guard timeLeft > 0 else { return }
        if sender.title(for: .normal) == current?.hebrew { score += 1 }
        nextQuestion()
    }

    private func finish() {
        timer?.invalidate()
        RealtimeDatabaseService.shared.addXP(score * 5)
        let alert = UIAlertController(title: "Time's up!",
                                     message: "You scored \(score) points.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
