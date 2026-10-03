import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errors: [String: String] = [:]
    @State private var serverError: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Create your account")
                        .font(.title2.weight(.bold))
                    Text("Start tracking your finances today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    if let err = serverError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ValidatedField(label: "Name", placeholder: "Your full name", text: $name, error: errors["name"] ?? "")
                    ValidatedField(label: "Username", placeholder: "username", text: $username, error: errors["username"] ?? "")
                    ValidatedField(label: "Email", placeholder: "you@example.com", text: $email, error: errors["email"] ?? "", keyboardType: .emailAddress)
                    ValidatedField(label: "Password", placeholder: "Choose a password", text: $password, error: errors["password"] ?? "", isSecure: true)

                    Button(action: handleSubmit) {
                        Group {
                            if isSubmitting { ProgressView() }
                            else { Text("Sign Up").frame(maxWidth: .infinity) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Button("Already have an account? Log in") { dismiss() }
                    .font(.footnote)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func validate() -> Bool {
        errors = [:]
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors["name"] = "Name is required" }
        let u = username.trimmingCharacters(in: .whitespaces)
        if u.isEmpty { errors["username"] = "Username is required" }
        let e = email.trimmingCharacters(in: .whitespaces)
        if e.isEmpty { errors["email"] = "Email is required" }
        else if !e.contains("@") { errors["email"] = "Enter a valid email address" }
        if password.count < 6 { errors["password"] = "Password must be at least 6 characters" }
        return errors.isEmpty
    }

    private func handleSubmit() {
        serverError = nil
        guard validate() else { return }
        isSubmitting = true
        Task {
            do {
                try await auth.signUp(
                    username: username.trimmingCharacters(in: .whitespaces),
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                serverError = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
