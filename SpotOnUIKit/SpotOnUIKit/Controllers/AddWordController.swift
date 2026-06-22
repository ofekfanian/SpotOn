import UIKit

// MARK: AddWordController
class AddWordController: UIViewController {

    var onSave: ((Word) -> Void)?

    private let wordField = AddWordController.field("English word")
    private let hebrewField = AddWordController.field("Hebrew translation")
    private let frenchField = AddWordController.field("French translation")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Word"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save Word", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        saveButton.tintColor = .white
        saveButton.backgroundColor = .crystalBlue
        saveButton.layer.cornerRadius = 14
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [wordField, hebrewField, frenchField, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func saveTapped() {
        guard let w = wordField.text, !w.isEmpty else { return }
        let word = Word(word: w,
                        hebrew: hebrewField.text ?? "",
                        french: frenchField.text ?? "",
                        level: "Custom")
        onSave?(word)
        navigationController?.popViewController(animated: true)
    }

    private static func field(_ placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return tf
    }
}
