import UIKit
import FirebaseFirestore

// MARK: WordsController
class WordsController: UIViewController {

    private var words: [Word] = []
    private var collectionView: UICollectionView!
    private var listener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Words"
        view.backgroundColor = .systemGroupedBackground
        setupNavBar()
        setupCollectionView()
        connect()
    }

    deinit { listener?.remove() }

    // Stream the logged-in user's words from Firestore.
    private func connect() {
        listener = FirestoreService.shared.listenWords { [weak self] words in
            self?.words = words.isEmpty ? Word().mockData() : words
            self?.collectionView.reloadData()
        }
    }

    // Size classes (whiteboard): Compact width → 1 column, Regular width → 2.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in self.collectionView.collectionViewLayout.invalidateLayout() }
    }

    private func setupNavBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped))
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(WordCell.self, forCellWithReuseIdentifier: WordCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // Column count driven by the horizontal size class.
    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, env in
            let isRegular = env.traitCollection.horizontalSizeClass == .regular
            let columns = isRegular ? 2 : 1
            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
                heightDimension: .fractionalHeight(1.0)))
            item.contentInsets = .init(top: 6, leading: 8, bottom: 6, trailing: 8)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(96)), subitems: Array(repeating: item, count: columns))
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 12, leading: 8, bottom: 12, trailing: 8)
            return section
        }
    }

    @objc private func addTapped() {
        let addVC = AddWordController()
        addVC.onSave = { word in
            FirestoreService.shared.addWord(word)
            RealtimeDatabaseService.shared.addXP(10)
        }
        navigationController?.pushViewController(addVC, animated: true)
    }
}

// MARK: DataSource & Delegate
extension WordsController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        words.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WordCell.reuseID, for: indexPath) as! WordCell
        cell.configure(words[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        navigationController?.pushViewController(WordDetailController(word: words[indexPath.item]), animated: true)
    }

    // Long-press to delete (only Firestore-backed words have an id).
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        let word = words[indexPath.item]
        guard word.id != nil else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                FirestoreService.shared.deleteWord(word)
            }
            return UIMenu(children: [delete])
        }
    }
}
