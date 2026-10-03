import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var email = ""
    @State private var emailError = ""
    @State private var saved = false

    var body: some View {
        List {
            if let user = auth.user {
                Section {
                    // Avatar
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(Color.accentColor)
                                .frame(width: 64, height: 64)
                            Text(getInitials(user.name))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Account Details") {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Username", value: user.username)
                }

                Section("Email") {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !emailError.isEmpty {
                        Text(emailError).font(.caption).foregroundStyle(.red)
                    }
                    if saved {
                        Text("Email updated.").font(.caption).foregroundStyle(.green)
                    }
                    Button("Save Changes") { saveEmail() }
                }

                Section {
                    Button("Log Out", role: .destructive) { auth.signOut() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .onAppear { email = auth.user?.email ?? "" }
    }

    private func saveEmail() {
        emailError = ""
        saved = false
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || !trimmed.contains("@") || !trimmed.contains(".") {
            emailError = "Enter a valid email address"
            return
        }
        auth.updateEmail(trimmed)
        saved = true
    }
}
