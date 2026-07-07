import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var scheme
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 36) {
                    Spacer().frame(height: 56)
                    VStack(spacing: 10) {
                        SpotOnLogoView(height: 76)
                        Text("Master English, One Word at a Time")
                            .font(.subheadline).foregroundColor(.secondary)
                    }

                    VStack(spacing: 18) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)

                        Group {
                            CrystalField("Email", text: $email, isSecure: false)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            CrystalField("Password", text: $password, isSecure: true)
                            if isSignUp { CrystalField("Confirm Password", text: $confirmPassword, isSecure: true) }
                        }

                        if let err = authVM.errorMessage {
                            Text(err).foregroundColor(.red).font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button { Task { await submit() } } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(LinearGradient.crystal)
                                if isLoading { ProgressView().tint(.white) }
                                else { Text(isSignUp ? "Sign Up" : "Sign In").font(.headline).foregroundColor(.white) }
                            }
                            .frame(height: 52)
                        }
                        .shadow(color: Color.crystalBlue.opacity(0.35), radius: 10, y: 4)
                        .disabled(isLoading)

                        Button {
                            withAnimation(.spring(duration: 0.3)) { isSignUp.toggle() }
                            authVM.errorMessage = nil
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.footnote).foregroundStyle(LinearGradient.crystalShort)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(28)
                    .overlay(RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(LinearGradient.crystal.opacity(0.4), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 24, y: 8)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
        }
    }

    private func submit() async {
        isLoading = true
        if isSignUp {
            guard password == confirmPassword else {
                authVM.errorMessage = "Passwords don't match"; isLoading = false; return
            }
            await authVM.signUp(email: email, password: password)
        } else {
            await authVM.signIn(email: email, password: password)
        }
        isLoading = false
    }
}

private struct CrystalField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    init(_ placeholder: String, text: Binding<String>, isSecure: Bool) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
    }

    var body: some View {
        Group {
            if isSecure { SecureField(placeholder, text: $text) }
            else { TextField(placeholder, text: $text) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.crystalBlue.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Color(hex:)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

#Preview("Light") { AuthView().environmentObject(AuthViewModel()).preferredColorScheme(.light) }
#Preview("Dark")  { AuthView().environmentObject(AuthViewModel()).preferredColorScheme(.dark) }
