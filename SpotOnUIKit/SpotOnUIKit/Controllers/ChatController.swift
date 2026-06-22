import UIKit

// MARK: ChatController
// AI English tutor backed by Gemini (URLSession).
class ChatController: UIViewController {

    private struct Message { let role: String; let text: String }
    private var messages: [Message] = [
        Message(role: "model", text: "Hey! I'm your SpotOn English tutor. What would you like to talk about today?")
    ]

    private let tableView = UITableView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var inputBottom: NSLayoutConstraint!

    private let model = "gemini-1.5-flash"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Tutor"
        setupUI()
        observeKeyboard()
    }

    private func setupUI() {
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "msg")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let bar = UIView()
        bar.backgroundColor = .secondarySystemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        inputField.placeholder = "Type in English..."
        inputField.borderStyle = .roundedRect
        inputField.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(inputField)

        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = .crystalBlue
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(sendButton)

        inputBottom = bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bar.topAnchor),

            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottom,

            inputField.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            inputField.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            inputField.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: Keyboard
    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.height - frame.origin.y - view.safeAreaInsets.bottom)
        inputBottom.constant = -overlap
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func sendTapped() {
        let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        inputField.text = ""
        append(Message(role: "user", text: text))
        Task { await callGemini() }
    }

    private func append(_ msg: Message) {
        messages.append(msg)
        tableView.reloadData()
        tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
    }

    // MARK: Gemini
    private func callGemini() async {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else { return }
        let contents = messages.suffix(10).map { ["role": $0.role == "model" ? "model" : "user",
                                                  "parts": [["text": $0.text]]] }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": "You are a friendly English tutor. Keep replies short (1-2 sentences) and ask a follow-up question."]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": 150, "temperature": 0.7]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            let reply = parts?.first?["text"] as? String ?? "Could you say that again?"
            append(Message(role: "model", text: reply))
        } catch {
            append(Message(role: "model", text: "Couldn't reach the tutor. Check your connection."))
        }
    }
}

// MARK: DataSource
extension ChatController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "msg", for: indexPath)
        let msg = messages[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = msg.text
        config.textProperties.color = msg.role == "user" ? .white : .label
        cell.contentConfiguration = config
        cell.backgroundColor = .clear
        // Bubble styling per side.
        cell.contentView.backgroundColor = msg.role == "user" ? .crystalBlue : .secondarySystemBackground
        cell.contentView.layer.cornerRadius = 14
        cell.contentView.layoutMargins = .init(top: 10, left: 14, bottom: 10, right: 14)
        return cell
    }
}
