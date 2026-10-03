import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published var user: User? = nil
    @Published var ready = false

    init() {
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        guard KeychainHelper.getToken() != nil else {
            ready = true
            return
        }
        do {
            user = try await AuthAPI.me()
        } catch {
            KeychainHelper.deleteToken()
        }
        ready = true
    }

    func signUp(username: String, name: String, email: String, password: String) async throws {
        let res = try await AuthAPI.signup(username: username, name: name, email: email, password: password)
        KeychainHelper.setToken(res.accessToken)
        user = res.user
    }

    func signIn(email: String, password: String) async throws {
        let res = try await AuthAPI.login(email: email, password: password)
        KeychainHelper.setToken(res.accessToken)
        user = res.user
    }

    func signOut() {
        KeychainHelper.deleteToken()
        user = nil
    }

    func updateEmail(_ email: String) {
        user?.email = email
    }
}
