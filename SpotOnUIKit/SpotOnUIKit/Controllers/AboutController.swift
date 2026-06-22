import UIKit

// MARK: AboutController
class AboutController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "About"
        setupUI()
    }

    private func setupUI() {
        let icon = UIImageView(image: UIImage(systemName: "target"))
        icon.tintColor = .crystalBlue
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let title = label("SpotOn", font: .boldSystemFont(ofSize: 32), color: .crystalBlue, align: .center)
        let tagline = label("Master English, One Word at a Time", font: .systemFont(ofSize: 15), color: .secondaryLabel, align: .center)
        let desc = label("Capture words from real life, practice them in fun games, and chat with an AI tutor — in English, Hebrew, and French.",
                         font: .systemFont(ofSize: 15), color: .label, align: .center)
        let version = label("Version 1.0.0  ·  Built with UIKit", font: .systemFont(ofSize: 12), color: .secondaryLabel, align: .center)

        let stack = UIStackView(arrangedSubviews: [icon, title, tagline, desc, version])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func label(_ text: String, font: UIFont, color: UIColor, align: NSTextAlignment) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.textAlignment = align
        l.numberOfLines = 0
        return l
    }
}
