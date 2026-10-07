import Foundation

private let utcCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func advanceIncome(_ date: Date, by frequency: IncomeFrequency) -> Date {
    switch frequency {
    case .weekly:      return utcCal.date(byAdding: .weekOfYear, value: 1,   to: date) ?? date
    case .biweekly:    return utcCal.date(byAdding: .weekOfYear, value: 2,   to: date) ?? date
    case .semimonthly: return utcCal.date(byAdding: .day,        value: 15,  to: date) ?? date
    case .monthly:     return utcCal.date(byAdding: .month,      value: 1,   to: date) ?? date
    }
}

private func retreatIncome(_ date: Date, by frequency: IncomeFrequency) -> Date {
    switch frequency {
    case .weekly:      return utcCal.date(byAdding: .weekOfYear, value: -1,  to: date) ?? date
    case .biweekly:    return utcCal.date(byAdding: .weekOfYear, value: -2,  to: date) ?? date
    case .semimonthly: return utcCal.date(byAdding: .day,        value: -15, to: date) ?? date
    case .monthly:     return utcCal.date(byAdding: .month,      value: -1,  to: date) ?? date
    }
}

// Returns the total income deposited into an account in the range [anchor, today].
private func incomeDeposited(_ income: Income, from anchor: Date, to today: Date) -> Double {
    guard var current = parseISODate(income.nextPayDate) else { return 0 }
    let amount = effectiveIncomeAmount(income)

    // Normalize: find the first occurrence of this schedule on or after anchor.
    if current >= anchor {
        // Walk backward until just before anchor, then step forward once.
        while current >= anchor { current = retreatIncome(current, by: income.frequency) }
        current = advanceIncome(current, by: income.frequency)
    } else {
        // Walk forward to the first occurrence on or after anchor.
        while current < anchor { current = advanceIncome(current, by: income.frequency) }
    }

    // Sum every occurrence up to and including today.
    var total = 0.0
    while current <= today {
        total += amount
        current = advanceIncome(current, by: income.frequency)
    }
    return total
}

/// account.balance is the value the user entered at account.created_at.
/// Live balance subtracts transactions and subscription charges since then,
/// and adds income deposited to the account since then.
func liveAccountBalance(_ account: Account, transactions: [Transaction], subscriptions: [Subscription], incomes: [Income] = []) -> Double {
    let anchor = String(account.createdAt.prefix(10))
    let today = todayISOString()

    let spent = transactions
        .filter { $0.accountId == account.id && $0.date >= anchor }
        .reduce(0.0) { $0 + $1.amount }

    let charges = subscriptions
        .filter { $0.accountId == account.id && $0.active && $0.nextBillingDate >= anchor && $0.nextBillingDate <= today }
        .reduce(0.0) { $0 + $1.amount }

    let deposited: Double
    if let fromDate = parseISODate(anchor), let toDate = parseISODate(today) {
        deposited = incomes
            .filter { $0.accountId == account.id && $0.active }
            .reduce(0.0) { $0 + incomeDeposited($1, from: fromDate, to: toDate) }
    } else {
        deposited = 0
    }

    return account.balance - spent - charges + deposited
}

func totalLiveBalance(_ accounts: [Account], transactions: [Transaction], subscriptions: [Subscription], incomes: [Income] = []) -> Double {
    accounts.reduce(0.0) { $0 + liveAccountBalance($1, transactions: transactions, subscriptions: subscriptions, incomes: incomes) }
}
