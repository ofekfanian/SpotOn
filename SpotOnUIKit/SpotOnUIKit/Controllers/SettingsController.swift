import UIKit

// MARK: SettingsController
class SettingsController: UIViewController {

    private let segmented = UISegmentedControl(items: AppAppearance.allCases.map { $0.label })

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Settings"
        setupUI()
    }

    private func setupUI() {
        let appearanceTitle = sectionLabel("Appearance")
        segmented.selectedSegmentIndex = AppSettings.appearance.rawValue
        segmented.addTarget(self, action: #selector(appearanceChanged), for: .valueChanged)

        let languagesButton = UIButton(type: .system)
        languagesButton.contentHorizontalAlignment = .leading
        languagesButton.titleLabel?.font = .systemFont(ofSize: 17)
        let target = Language(rawValue: AppSettings.targetLanguage)?.name ?? "English"
        let native = Language(rawValue: AppSettings.nativeLanguage)?.name ?? "Hebrew"
        languagesButton.setTitle("Languages: learn \(target) · speak \(native)", for: .normal)
        languagesButton.addTarget(self, action: #selector(languagesTapped), for: .touchUpInside)

        let aboutButton = UIButton(type: .system)
        aboutButton.setTitle("About SpotOn", for: .normal)
        aboutButton.contentHorizontalAlignment = .leading
        aboutButton.titleLabel?.font = .systemFont(ofSize: 17)
        aboutButton.addTarget(self, action: #selector(aboutTapped), for: .touchUpInside)

        let statsLabel = sectionLabel("")
        statsLabel.font = .systemFont(ofSize: 14)
        statsLabel.textColor = .secondaryLabel
        statsLabel.numberOfLines = 0
        let email = AuthService.shared.profile?.email ?? "—"
        statsLabel.text = "\(email)\nXP \(RealtimeDatabaseService.shared.xp) · Streak \(RealtimeDatabaseService.shared.streak)d"

        let signOutButton = UIButton(type: .system)
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.contentHorizontalAlignment = .leading
        signOutButton.titleLabel?.font = .systemFont(ofSize: 17)
        signOutButton.tintColor = .systemRed
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)

        let versionLabel = sectionLabel("Version 1.0.0")
        versionLabel.font = .systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [statsLabel, appearanceTitle, segmented, languagesButton, aboutButton, signOutButton, versionLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(28, after: segmented)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func appearanceChanged() {
        AppSettings.appearance = AppAppearance(rawValue: segmented.selectedSegmentIndex) ?? .system
    }

    @objc private func aboutTapped() {
        navigationController?.pushViewController(AboutController(), animated: true)
    }

    @objc private func signOutTapped() {
        let alert = UIAlertController(title: "Sign Out?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            AuthService.shared.signOut()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func languagesTapped() {
        let vc = OnboardingController()
        vc.onDone = { [weak self] in
            self?.dismiss(animated: true)
            self?.view.subviews.forEach { $0.removeFromSuperview() }
            self?.setupUI()   // rebuild with the new language labels
        }
        present(vc, animated: true)
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .boldSystemFont(ofSize: 17)
        return l
    }
}
