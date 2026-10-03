import Foundation

func formatCurrency(_ amount: Double) -> String {
    String(format: "$%.2f", amount)
}

func getInitials(_ name: String) -> String {
    let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
    return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
}

let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "UTC")
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

func parseISODate(_ str: String) -> Date? {
    isoDateFormatter.date(from: str)
}

func formatISODate(_ date: Date) -> String {
    isoDateFormatter.string(from: date)
}

func todayISOString() -> String {
    formatISODate(Date())
}
