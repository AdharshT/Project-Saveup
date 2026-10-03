import Foundation

private let monthlyFactors: [String: Double] = [
    "weekly": 52.0 / 12.0,
    "biweekly": 26.0 / 12.0,
    "semimonthly": 2.0,
    "monthly": 1.0,
    "quarterly": 1.0 / 3.0,
    "yearly": 1.0 / 12.0
]

func monthlyEquivalent(_ amount: Double, cycle: String) -> Double {
    amount * (monthlyFactors[cycle] ?? 1.0)
}

private func stepBack(_ date: Date, cycle: String) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    switch cycle {
    case "weekly":   return cal.date(byAdding: .day, value: -7, to: date)!
    case "quarterly": return cal.date(byAdding: .month, value: -3, to: date)!
    case "yearly":   return cal.date(byAdding: .year, value: -1, to: date)!
    default:         return cal.date(byAdding: .month, value: -1, to: date)!
    }
}

/// One cycle after dateStr. Mirrors the backend calculation for display purposes.
func addBillingInterval(_ dateStr: String, cycle: String) -> String {
    guard var date = parseISODate(dateStr) else { return dateStr }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    switch cycle {
    case "weekly":   date = cal.date(byAdding: .day, value: 7, to: date)!
    case "quarterly": date = cal.date(byAdding: .month, value: 3, to: date)!
    case "yearly":   date = cal.date(byAdding: .year, value: 1, to: date)!
    default:         date = cal.date(byAdding: .month, value: 1, to: date)!
    }
    return formatISODate(date)
}

/// How much is actually billed within a given month string ("yyyy-MM").
func amountDueInMonth(_ amount: Double, cycle: String, nextBillingDate: String, monthStr: String) -> Double {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let parts = monthStr.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 2 else { return 0 }
    let (year, month) = (parts[0], parts[1])
    guard let monthStart = cal.date(from: DateComponents(year: year, month: month, day: 1)),
          let monthEnd = cal.date(from: DateComponents(year: year, month: month + 1, day: 0)) else { return 0 }

    guard var cursor = parseISODate(nextBillingDate) else { return 0 }
    var iterations = 0
    while cursor > monthEnd, iterations < 1000 {
        cursor = stepBack(cursor, cycle: cycle)
        iterations += 1
    }
    var occurrences = 0
    while cursor >= monthStart, iterations < 2000 {
        if cursor <= monthEnd { occurrences += 1 }
        cursor = stepBack(cursor, cycle: cycle)
        iterations += 1
    }
    return Double(occurrences) * amount
}
