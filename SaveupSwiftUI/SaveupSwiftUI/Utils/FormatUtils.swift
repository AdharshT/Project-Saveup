import Foundation

func formatCurrency(_ amount: Double) -> String {
    String(format: "$%.2f", amount)
}

func getInitials(_ name: String) -> String {
    let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
    return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
}

func parseISODate(_ str: String) -> Date? {
    let parts = str.split(separator: "-")
    guard parts.count == 3,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          let day = Int(parts[2]) else { return nil }
    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = day
    comps.hour = 12  // noon avoids DST edge cases at midnight
    return Calendar.current.date(from: comps)
}

func formatISODate(_ date: Date) -> String {
    let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}

func todayISOString() -> String {
    formatISODate(Date())
}
