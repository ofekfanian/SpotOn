import UIKit
import AuthenticationServices

// MARK: AuthController
// Email/password + Sign in with Apple.
class AuthController: UIViewController {

    private var isSignUp = false

    private let titleLabel = UILabel()
    private let emailField = AuthController.field("Email", secure: false)
    private let passwordField = AuthController.field("Password", secure: true)
    private let primaryButton = UIButton(type: .system)
    private let toggleButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let logo = UILabel()
        logo.text = "SpotOn"
        logo.font = .boldSystemFont(ofSize: 42)
        logo.textColor = .crystalBlue
        logo.textAlignment = .center

        titleLabel.text = "Welcome Back"
        titleLabel.font = .boldSystemFont(ofSize: 22)

        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no

        primaryButton.setTitle("Sign In", for: .normal)
        primaryButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        primaryButton.tintColor = .white
        primaryButton.backgroundColor = .crystalBlue
        primaryButton.layer.cornerRadius = 14
        primaryButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: traitCollection.userInterfaceStyle == .dark ? .white : .black)
        appleButton.cornerRadius = 14
        appleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        appleButton.addTarget(self, action: #selector(appleTapped), for: .touchUpInside)

        toggleButton.setTitle("Don't have an account? Sign Up", for: .normal)
        toggleButton.titleLabel?.font = .systemFont(ofSize: 14)
        toggleButton.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)

        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [logo, titleLabel, emailField, passwordField,
                                                   errorLabel, primaryButton, appleButton, spinner, toggleButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(28, after: logo)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])
    }

    @objc private func toggleMode() {
        isSignUp.toggle()
        titleLabel.text = isSignUp ? "Create Account" : "Welcome Back"
        primaryButton.setTitle(isSignUp ? "Sign Up" : "Sign In", for: .normal)
        toggleButton.setTitle(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up", for: .normal)
        errorLabel.text = nil
    }

    @objc private func primaryTapped() {
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""
        guard !email.isEmpty, !password.isEmpty else { errorLabel.text = "Enter email and password."; return }
        view.endEditing(true)
        spinner.startAnimating()
        let handler: (String?) -> Void = { [weak self] error in
            self?.spinner.stopAnimating()
            self?.errorLabel.text = error
        }
        if isSignUp { AuthService.shared.signUp(email: email, password: password, completion: handler) }
        else { AuthService.shared.signIn(email: email, password: password, completion: handler) }
    }

    @objc private func appleTapped() {
        spinner.startAnimating()
        AuthService.shared.startSignInWithApple(presenting: self) { [weak self] error in
            self?.spinner.stopAnimating()
            self?.errorLabel.text = error
        }
    }

    private static func field(_ placeholder: String, secure: Bool) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.isSecureTextEntry = secure
        tf.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return tf
    }
}
