import Foundation

// Change this to point at your server. Localhost works in the iOS Simulator.
let apiBaseURL = "https://project-saveup-production.up.railway.app"

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .serverError(let msg): msg
        }
    }
}

private struct APIErrorBody: Decodable {
    let detail: String?
}

private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.keyEncodingStrategy = .convertToSnakeCase
    return e
}()

private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

private func request<T: Decodable>(
    path: String,
    method: String = "GET",
    body: (any Encodable)? = nil
) async throws -> T {
    guard let url = URL(string: apiBaseURL + path) else {
        throw APIError.serverError("Invalid URL")
    }
    var req = URLRequest(url: url, timeoutInterval: 15)
    req.httpMethod = method
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
    if let token = KeychainHelper.getToken() {
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    if let body {
        req.httpBody = try encoder.encode(body)
    }

    let (data, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }
    if !(200..<300).contains(http.statusCode) {
        let detail = (try? decoder.decode(APIErrorBody.self, from: data))?.detail
            ?? String(data: data, encoding: .utf8)
            ?? "\(method) \(path) failed: \(http.statusCode)"
        throw APIError.serverError(detail)
    }
    return try decoder.decode(T.self, from: data)
}

private func requestVoid(
    path: String,
    method: String,
    body: (any Encodable)? = nil
) async throws {
    guard let url = URL(string: apiBaseURL + path) else {
        throw APIError.serverError("Invalid URL")
    }
    var req = URLRequest(url: url, timeoutInterval: 15)
    req.httpMethod = method
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
    if let token = KeychainHelper.getToken() {
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    if let body {
        req.httpBody = try encoder.encode(body)
    }
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }
    if !(200..<300).contains(http.statusCode) {
        let detail = (try? decoder.decode(APIErrorBody.self, from: data))?.detail
            ?? String(data: data, encoding: .utf8)
            ?? "\(method) \(path) failed: \(http.statusCode)"
        throw APIError.serverError(detail)
    }
}

// MARK: - Auth

enum AuthAPI {
    struct SignupBody: Encodable {
        let username: String
        let name: String
        let email: String
        let password: String
    }
    struct LoginBody: Encodable {
        let email: String
        let password: String
    }
    struct ResetPasswordBody: Encodable {
        let email: String
        let newPassword: String
    }

    static func signup(username: String, name: String, email: String, password: String) async throws -> AuthResponse {
        try await request(path: "/auth/signup", method: "POST", body: SignupBody(username: username, name: name, email: email, password: password))
    }
    static func login(email: String, password: String) async throws -> AuthResponse {
        try await request(path: "/auth/login", method: "POST", body: LoginBody(email: email, password: password))
    }
    static func resetPassword(email: String, newPassword: String) async throws {
        try await requestVoid(path: "/auth/reset-password", method: "POST", body: ResetPasswordBody(email: email, newPassword: newPassword))
    }
    static func me() async throws -> User {
        try await request(path: "/auth/me")
    }
}

// MARK: - Banks

enum BanksAPI {
    static func list() async throws -> [Bank] { try await request(path: "/banks") }
    static func create(_ input: BankInput) async throws -> Bank {
        try await request(path: "/banks", method: "POST", body: input)
    }
    static func update(id: Int, _ input: BankInput) async throws -> Bank {
        try await request(path: "/banks/\(id)", method: "PUT", body: input)
    }
    static func remove(id: Int) async throws {
        try await requestVoid(path: "/banks/\(id)", method: "DELETE")
    }
}

// MARK: - Accounts

enum AccountsAPI {
    static func list() async throws -> [Account] { try await request(path: "/accounts") }
    static func create(_ input: AccountInput) async throws -> Account {
        try await request(path: "/accounts", method: "POST", body: input)
    }
    static func update(id: Int, _ input: AccountInput) async throws -> Account {
        try await request(path: "/accounts/\(id)", method: "PUT", body: input)
    }
    static func remove(id: Int) async throws {
        try await requestVoid(path: "/accounts/\(id)", method: "DELETE")
    }
}

// MARK: - Subscriptions

enum SubscriptionsAPI {
    static func list() async throws -> [Subscription] { try await request(path: "/subscriptions") }
    static func create(_ input: SubscriptionInput) async throws -> Subscription {
        try await request(path: "/subscriptions", method: "POST", body: input)
    }
    static func update(id: Int, _ input: SubscriptionInput) async throws -> Subscription {
        try await request(path: "/subscriptions/\(id)", method: "PUT", body: input)
    }
    static func updateActive(id: Int, active: Bool) async throws -> Subscription {
        try await request(path: "/subscriptions/\(id)", method: "PUT", body: SubscriptionActiveUpdate(active: active))
    }
    static func remove(id: Int) async throws {
        try await requestVoid(path: "/subscriptions/\(id)", method: "DELETE")
    }
}

// MARK: - Incomes

enum IncomesAPI {
    static func list() async throws -> [Income] { try await request(path: "/incomes") }
    static func create(_ input: IncomeInput) async throws -> Income {
        try await request(path: "/incomes", method: "POST", body: input)
    }
    static func update(id: Int, _ input: IncomeInput) async throws -> Income {
        try await request(path: "/incomes/\(id)", method: "PUT", body: input)
    }
    static func remove(id: Int) async throws {
        try await requestVoid(path: "/incomes/\(id)", method: "DELETE")
    }
    static func next() async throws -> [NextPaycheck] {
        try await request(path: "/incomes/upcoming/next")
    }
}

// MARK: - Transactions

enum TransactionsAPI {
    static func list() async throws -> [Transaction] { try await request(path: "/transactions") }
    static func create(_ input: TransactionInput) async throws -> Transaction {
        try await request(path: "/transactions", method: "POST", body: input)
    }
    static func update(id: Int, _ input: TransactionInput) async throws -> Transaction {
        try await request(path: "/transactions/\(id)", method: "PUT", body: input)
    }
    static func remove(id: Int) async throws {
        try await requestVoid(path: "/transactions/\(id)", method: "DELETE")
    }
}

// MARK: - Summary

enum SummaryAPI {
    static func monthly(months: Int = 6, accountId: Int? = nil) async throws -> MonthlyComparison {
        var path = "/summary/monthly?months=\(months)"
        if let id = accountId { path += "&account_id=\(id)" }
        return try await request(path: path)
    }
}

// MARK: - Affordability

enum AffordabilityAPI {
    struct CheckBody: Encodable { let items: [BasketItemInput] }

    static func check(items: [BasketItemInput]) async throws -> AffordabilityResponse {
        try await request(path: "/affordability/check", method: "POST", body: CheckBody(items: items))
    }
    static func history() async throws -> [AffordabilityResponse] {
        try await request(path: "/affordability/history")
    }
    static func removeHistory(id: Int) async throws {
        try await requestVoid(path: "/affordability/history/\(id)", method: "DELETE")
    }
}
