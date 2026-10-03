import Foundation

/// account.balance is the value the user entered at account.created_at.
/// Live balance subtracts transactions and subscription charges since then.
func liveAccountBalance(_ account: Account, transactions: [Transaction], subscriptions: [Subscription]) -> Double {
    let anchor = String(account.createdAt.prefix(10))
    let today = todayISOString()

    let spent = transactions
        .filter { $0.accountId == account.id && $0.date >= anchor }
        .reduce(0.0) { $0 + $1.amount }

    let charges = subscriptions
        .filter { $0.accountId == account.id && $0.active && $0.nextBillingDate >= anchor && $0.nextBillingDate <= today }
        .reduce(0.0) { $0 + $1.amount }

    return account.balance - spent - charges
}

func totalLiveBalance(_ accounts: [Account], transactions: [Transaction], subscriptions: [Subscription]) -> Double {
    accounts.reduce(0.0) { $0 + liveAccountBalance($1, transactions: transactions, subscriptions: subscriptions) }
}
