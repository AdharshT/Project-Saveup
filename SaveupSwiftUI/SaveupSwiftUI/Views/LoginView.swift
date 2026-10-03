import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var emailError = ""
    @State private var passwordError = ""
    @State private var serverError: String?
    @State private var isSubmitting = false

    private var isValid: Bool {
        emailError.isEmpty && passwordError.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Log in to Saveup")
                        .font(.title2.weight(.bold))
                    Text("Pick up right where you left off.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    if let err = serverError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ValidatedField(label: "Email", placeholder: "you@example.com", text: $email, error: emailError, keyboardType: .emailAddress)

                    ValidatedField(label: "Password", placeholder: "••••••••", text: $password, error: passwordError, isSecure: true)

                    HStack {
                        Spacer()
                        NavigationLink("Forgot password?") {
                            ForgotPasswordView()
                        }
                        .font(.footnote)
                    }

                    Button(action: handleSubmit) {
                        Group {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Log In")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                NavigationLink {
                    SignUpView()
                } label: {
                    Text("New here? ") + Text("Sign up").foregroundColor(.accentColor)
                }
                .font(.footnote)
            }
            .padding(.bottom, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func validate() -> Bool {
        emailError = ""
        passwordError = ""
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)
        if emailTrimmed.isEmpty {
            emailError = "Email is required"
        } else if !emailTrimmed.contains("@") || !emailTrimmed.contains(".") {
            emailError = "Enter a valid email address"
        }
        if password.isEmpty {
            passwordError = "Password is required"
        }
        return emailError.isEmpty && passwordError.isEmpty
    }

    private func handleSubmit() {
        serverError = nil
        guard validate() else { return }
        isSubmitting = true
        Task {
            do {
                try await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            } catch {
                serverError = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

struct ValidatedField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var error: String = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.footnote.weight(.medium))
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(error.isEmpty ? Color.clear : .red, lineWidth: 1))

            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
