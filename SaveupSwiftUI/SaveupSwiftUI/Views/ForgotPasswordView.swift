import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var newPassword = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var success = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Reset Password")
                        .font(.title2.weight(.bold))
                    Text("Enter your email and a new password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    if let err = error {
                        Text(err).font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if success {
                        Text("Password updated. You can now log in.")
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ValidatedField(label: "Email", placeholder: "you@example.com", text: $email, keyboardType: .emailAddress)
                    ValidatedField(label: "New Password", placeholder: "New password", text: $newPassword, isSecure: true)

                    Button(action: handleSubmit) {
                        Group {
                            if isSubmitting { ProgressView() }
                            else { Text("Reset Password").frame(maxWidth: .infinity) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || success)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleSubmit() {
        error = nil
        let e = email.trimmingCharacters(in: .whitespaces)
        if e.isEmpty || !e.contains("@") {
            error = "Enter a valid email address"
            return
        }
        if newPassword.count < 6 {
            error = "Password must be at least 6 characters"
            return
        }
        isSubmitting = true
        Task {
            do {
                try await AuthAPI.resetPassword(email: e, newPassword: newPassword)
                success = true
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
