import UIKit

// MARK: DescribeImageController
// Shows a category photo; the learner describes it; Gemini Vision corrects
// grammar and checks whether the description matches the image.
// Images come from LoremFlickr (Creative Commons), filtered by category —
// never from Google Images (copyright).
class DescribeImageController: UIViewController {

    private let categories = ImageBankService.shared.categories
    private lazy var selectedCategory = categories.first ?? "nature"
    private var categoryButtons: [UIButton] = []

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let descriptionField = UITextField()
    private let checkButton = UIButton(type: .system)
    private let feedbackLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    private var currentImageData: Data?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Describe the Image"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(loadImage))
        setupUI()
        loadImage()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let categoryBar = makeCategoryBar()

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = 20
        imageView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let caption = label("Describe what you see in English:", font: .systemFont(ofSize: 15, weight: .medium), color: .label)

        descriptionField.placeholder = "e.g. There is a dog running on the beach"
        descriptionField.borderStyle = .roundedRect
        descriptionField.heightAnchor.constraint(equalToConstant: 48).isActive = true

        checkButton.setTitle("Check my sentence", for: .normal)
        checkButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        checkButton.tintColor = .white
        checkButton.backgroundColor = .crystalBlue
        checkButton.layer.cornerRadius = 14
        checkButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        checkButton.addTarget(self, action: #selector(checkTapped), for: .touchUpInside)

        feedbackLabel.font = .systemFont(ofSize: 16)
        feedbackLabel.numberOfLines = 0
        feedbackLabel.textColor = .label

        let stack = UIStackView(arrangedSubviews: [categoryBar, imageView, caption, descriptionField, checkButton, spinner, feedbackLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20)
        ])
    }

    // Horizontal, scrollable category chips — pick what interests you.
    private func makeCategoryBar() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        for cat in categories {
            let b = UIButton(type: .system)
            b.setTitle(cat.capitalized, for: .normal)
            b.titleLabel?.font = .boldSystemFont(ofSize: 14)
            b.contentEdgeInsets = .init(top: 8, left: 14, bottom: 8, right: 14)
            b.layer.cornerRadius = 18
            b.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryButtons.append(b)
            row.addArrangedSubview(b)
        }
        styleCategoryButtons()

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: 40),
            row.topAnchor.constraint(equalTo: scroll.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            row.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])
        return scroll
    }

    private func styleCategoryButtons() {
        for (i, b) in categoryButtons.enumerated() {
            let isSelected = categories[i] == selectedCategory
            b.backgroundColor = isSelected ? .crystalBlue : .secondarySystemBackground
            b.setTitleColor(isSelected ? .white : .label, for: .normal)
        }
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal)?.lowercased() else { return }
        selectedCategory = title
        styleCategoryButtons()
        loadImage()
    }

    // Category image from LoremFlickr (Creative Commons).
    @objc private func loadImage() {
        feedbackLabel.text = nil
        descriptionField.text = nil
        currentImageData = nil
        imageView.image = nil
        spinner.startAnimating()

        guard let url = ImageBankService.shared.randomImageURL(for: selectedCategory) else {
            spinner.stopAnimating()
            feedbackLabel.text = "No images for this category yet."
            return
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        Task {
            let image: UIImage? = await {
                if let (data, _) = try? await URLSession.shared.data(for: request), let img = UIImage(data: data) {
                    self.currentImageData = data
                    return img
                }
                return nil
            }()
            await MainActor.run {
                self.spinner.stopAnimating()
                self.imageView.image = image
                if image == nil { self.feedbackLabel.text = "Couldn't load an image. Check your connection." }
            }
        }
    }

    @objc private func checkTapped() {
        let text = descriptionField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty, let imageData = currentImageData else { return }
        view.endEditing(true)
        spinner.startAnimating()
        feedbackLabel.text = nil

        let prompt = """
        A learner wrote this description of the attached image: "\(text)". \
        Reply in 3 short lines, friendly and simple: \
        1) Corrected sentence (fix grammar/vocabulary, or say "Perfect!"). \
        2) Does it match the image? \
        3) One short tip.
        """
        Task {
            let reply = await GeminiService.shared.generate(prompt: prompt, imageData: imageData)
            await MainActor.run {
                self.spinner.stopAnimating()
                self.feedbackLabel.text = reply ?? "Couldn't reach the tutor. Check your connection."
            }
        }
    }

    private func label(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.numberOfLines = 0
        return l
    }
}
