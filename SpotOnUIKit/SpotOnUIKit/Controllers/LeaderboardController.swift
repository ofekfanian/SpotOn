import UIKit

// MARK: LeaderboardController
// Invite code + friends leaderboard (Firestore + Realtime DB).
class LeaderboardController: UIViewController {

    private var stats: [FriendStats] = []
    private let tableView = UITableView()
    private let codeLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Friends"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.badge.plus"), style: .plain, target: self, action: #selector(addFriendTapped))
        setupUI()
        load()
    }

    private func setupUI() {
        let header = UIStackView()
        header.axis = .vertical
        header.spacing = 4
        header.alignment = .center
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = .init(top: 16, left: 16, bottom: 16, right: 16)

        let caption = UILabel()
        caption.text = "Your invite code"
        caption.font = .systemFont(ofSize: 13)
        caption.textColor = .secondaryLabel
        codeLabel.font = .monospacedSystemFont(ofSize: 30, weight: .bold)
        codeLabel.textColor = .crystalBlue
        codeLabel.text = AuthService.shared.profile?.inviteCode ?? "------"
        header.addArrangedSubview(caption)
        header.addArrangedSubview(codeLabel)

        tableView.dataSource = self
        tableView.tableHeaderView = header
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "rank")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 90)
    }

    private func load() {
        guard let uid = AuthService.shared.uid else { return }
        let friends = AuthService.shared.profile?.friendUIDs ?? []
        FriendsService.shared.fetchLeaderboard(friendUIDs: friends, myUID: uid) { [weak self] stats in
            self?.stats = stats
            self?.tableView.reloadData()
        }
    }

    @objc private func addFriendTapped() {
        let alert = UIAlertController(title: "Add Friend", message: "Enter your friend's 6-character code", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "ABCDEF"; $0.autocapitalizationType = .allCharacters }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let code = alert.textFields?.first?.text, let uid = AuthService.shared.uid else { return }
            FriendsService.shared.addFriend(inviteCode: code, uid: uid) { error in
                if error == nil {
                    AuthService.shared.profile?.friendUIDs.append(contentsOf: [])
                    self?.load()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: DataSource
extension LeaderboardController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { stats.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "rank", for: indexPath)
        let stat = stats[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = "\(indexPath.row + 1).  \(stat.username)"
        config.secondaryText = "\(stat.xp) XP · \(stat.streak)d streak · \(stat.wordCount) words"
        if indexPath.row < 3 {
            config.image = UIImage(systemName: "medal.fill")
            config.imageProperties.tintColor = [UIColor.crystalGold, .lightGray, .brown][indexPath.row]
        }
        cell.contentConfiguration = config
        return cell
    }
}
