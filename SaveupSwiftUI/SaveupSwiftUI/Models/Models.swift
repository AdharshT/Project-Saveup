import Foundation

struct User: Codable, Equatable {
    let id: Int
    let username: String
    let name: String
    var email: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let user: User
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, quarterly, yearly
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum IncomeFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, biweekly, semimonthly, monthly
    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum PayType: String, Codable, CaseIterable, Identifiable {
    case fixed, hourly
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fixed: "Fixed amount"
        case .hourly: "Hourly"
        }
    }
}

struct Bank: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let createdAt: String
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking, savings, credit
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct Account: Codable, Identifiable, Equatable {
    let id: Int
    let bankId: Int
    let nickname: String
    let type: AccountType?
    let last4: String?
    let balance: Double
    let createdAt: String
}

struct Subscription: Codable, Identifiable, Equatable {
    let id: Int
    let accountId: Int
    let name: String
    let amount: Double
    let billingCycle: BillingCycle
    let category: String?
    let lastPaymentDate: String
    let nextBillingDate: String
    var active: Bool
    let notes: String?
    let createdAt: String
}

struct Income: Codable, Identifiable, Equatable {
    let id: Int
    let accountId: Int
    let source: String
    let amount: Double
    let frequency: IncomeFrequency
    let payType: PayType
    let hoursPerPeriod: Double?
    let payPeriodStart: String?
    let payPeriodEnd: String?
    let nextPayDate: String
    var active: Bool
    let createdAt: String
}

struct Transaction: Codable, Identifiable, Equatable {
    let id: Int
    let accountId: Int
    let description: String
    let amount: Double
    let category: String?
    let date: String
    let createdAt: String
}

struct NextPaycheck: Codable, Identifiable {
    let accountId: Int
    let source: String
    let amount: Double
    let date: String
    var id: String { "\(accountId)-\(source)-\(date)" }
}

struct MonthlyTotal: Codable {
    let month: String
    let total: Double
    let byCategory: [String: Double]
}

struct MonthlyComparison: Codable {
    let months: [MonthlyTotal]
}

struct BasketItemInput: Codable {
    let name: String
    let price: Double
}

struct BasketItem: Codable, Identifiable {
    let id: Int
    let name: String
    let price: Double
}

struct AffordabilityResponse: Codable, Identifiable {
    let id: Int
    let items: [BasketItem]
    let totalPrice: Double
    let canAfford: Bool
    let monthlyIncome: Double
    let monthlySubscriptionCost: Double
    let spendingThisMonth: Double
    let discretionaryBalance: Double
    let balanceAfterPurchase: Double
    let message: String
    let createdAt: String
}

// Input types for creating/updating resources
struct BankInput: Encodable {
    let name: String
}

struct AccountInput: Encodable {
    let bankId: Int
    let nickname: String
    let type: AccountType?
    let last4: String?
    let balance: Double
}

struct SubscriptionInput: Encodable {
    let accountId: Int
    let name: String
    let amount: Double
    let billingCycle: BillingCycle
    let category: String?
    let lastPaymentDate: String
    let active: Bool
    let notes: String?
}

struct SubscriptionActiveUpdate: Encodable {
    let active: Bool
}

struct IncomeInput: Encodable {
    let accountId: Int
    let source: String
    let amount: Double
    let frequency: IncomeFrequency
    let payType: PayType
    let hoursPerPeriod: Double?
    let payPeriodStart: String?
    let payPeriodEnd: String?
    let nextPayDate: String
    let active: Bool
}

struct TransactionInput: Encodable {
    let accountId: Int
    let description: String
    let amount: Double
    let category: String?
    let date: String
}
