import UIKit

// MARK: HomeController
class HomeController: UIViewController {

    private let streakValue = UILabel()
    private let xpValue = UILabel()
    private let idiomText = UILabel()
    private let idiomDef = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        title = "SpotOn"
        setupUI()
        RealtimeDatabaseService.shared.onUpdate = { [weak self] in self?.refreshStats() }
        loadIdiom()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStats()
    }

    private func setupUI() {
        let subtitle = makeLabel("Master English, One Word at a Time",
                                 font: .systemFont(ofSize: 15), color: .secondaryLabel)

        let stats = UIStackView(arrangedSubviews: [
            statChip(streakValue, "Streak", .crystalGold),
            statChip(xpValue, "XP", .crystalBlue),
            statChip(makeLabel("\(VocabularyService.shared.allWords().count)", font: .boldSystemFont(ofSize: 22), color: .crystalMint), "Words", .crystalMint),
        ])
        stats.axis = .horizontal
        stats.distribution = .fillEqually
        stats.spacing = 12

        let cta = primaryButton("Start Practice")
        cta.addTarget(self, action: #selector(practiceTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [subtitle, stats, idiomCard(), cta])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        refreshStats()
    }

    private func refreshStats() {
        streakValue.text = "\(RealtimeDatabaseService.shared.streak)d"
        xpValue.text = "\(RealtimeDatabaseService.shared.xp)"
    }

    private func loadIdiom() {
        let level = AuthService.shared.profile?.level ?? "intermediate"
        FirestoreService.shared.fetchTodayIdiom(level: level) { [weak self] idiom in
            self?.idiomText.text = "\u{201C}\(idiom.text)\u{201D}"
            self?.idiomDef.text = idiom.definition
        }
    }

    @objc private func practiceTapped() { tabBarController?.selectedIndex = 2 }

    private func statChip(_ value: UILabel, _ caption: String, _ color: UIColor) -> UIView {
        value.font = .boldSystemFont(ofSize: 22)
        value.textColor = color
        value.textAlignment = .center
        let c = makeLabel(caption, font: .systemFont(ofSize: 12), color: .secondaryLabel)
        let stack = UIStackView(arrangedSubviews: [value, c])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.backgroundColor = .secondarySystemBackground
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = .init(top: 14, left: 8, bottom: 14, right: 8)
        stack.layer.cornerRadius = 16
        return stack
    }

    private func idiomCard() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.roundedGlass(radius: 20)
        let title = makeLabel("Idiom of the Day", font: .boldSystemFont(ofSize: 13), color: .crystalBlue)
        idiomText.font = .boldSystemFont(ofSize: 20)
        idiomText.numberOfLines = 0
        idiomDef.font = .systemFont(ofSize: 14)
        idiomDef.textColor = .secondaryLabel
        idiomDef.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [title, idiomText, idiomDef])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])
        return container
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.numberOfLines = 0
        return l
    }

    private func primaryButton(_ title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 18)
        b.tintColor = .white
        b.backgroundColor = .crystalBlue
        b.layer.cornerRadius = 16
        b.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return b
    }
}
