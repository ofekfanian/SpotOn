import UIKit

// MARK: OnboardingController
// First launch: pick native language + the language to learn.
class OnboardingController: UIViewController {

    var onDone: (() -> Void)?

    private var native: Language = .hebrew
    private var target: Language = .english
    private var nativeButtons: [UIButton] = []
    private var targetButtons: [UIButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let logo = UILabel()
        logo.text = "SpotOn"
        logo.font = .boldSystemFont(ofSize: 40)
        logo.textColor = .crystalBlue
        logo.textAlignment = .center

        let nativeTitle = sectionTitle("I speak")
        let nativeRow = makeLanguageRow(selected: native) { [weak self] lang, buttons in
            self?.native = lang
            self?.nativeButtons = buttons
        }

        let targetTitle = sectionTitle("I want to learn")
        let targetRow = makeLanguageRow(selected: target) { [weak self] lang, buttons in
            self?.target = lang
            self?.targetButtons = buttons
        }

        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Learning", for: .normal)
        startButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        startButton.tintColor = .white
        startButton.backgroundColor = .crystalBlue
        startButton.layer.cornerRadius = 16
        startButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logo, nativeTitle, nativeRow, targetTitle, targetRow, startButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(32, after: logo)
        stack.setCustomSpacing(28, after: nativeRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    // A row of 3 language chips with single selection.
    private func makeLanguageRow(selected: Language, onSelect: @escaping (Language, [UIButton]) -> Void) -> UIStackView {
        var buttons: [UIButton] = []
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10

        for lang in Language.allCases {
            let b = UIButton(type: .system)
            b.setTitle(lang.nativeName, for: .normal)
            b.titleLabel?.font = .boldSystemFont(ofSize: 16)
            b.layer.cornerRadius = 14
            b.heightAnchor.constraint(equalToConstant: 56).isActive = true
            buttons.append(b)
            row.addArrangedSubview(b)
        }
        func style(_ chosen: Language) {
            for (i, b) in buttons.enumerated() {
                let isSel = Language.allCases[i] == chosen
                b.backgroundColor = isSel ? .crystalBlue : .secondarySystemBackground
                b.setTitleColor(isSel ? .white : .label, for: .normal)
            }
        }
        for (i, b) in buttons.enumerated() {
            b.addAction(UIAction { _ in
                let lang = Language.allCases[i]
                style(lang)
                onSelect(lang, buttons)
            }, for: .touchUpInside)
        }
        style(selected)
        onSelect(selected, buttons)
        return row
    }

    @objc private func startTapped() {
        AppSettings.nativeLanguage = native.rawValue
        AppSettings.targetLanguage = target.rawValue
        AppSettings.hasOnboarded = true
        // Persist to the user's Firestore profile too.
        AuthService.shared.completeOnboarding(native: native.rawValue, target: target.rawValue,
                                              level: AuthService.shared.profile?.level ?? "intermediate")
        onDone?()
    }

    private func sectionTitle(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .boldSystemFont(ofSize: 18)
        return l
    }
}
