import Foundation

struct ParsedTransaction: Identifiable {
    let id = UUID()
    let date: Date
    let description: String
    let amount: Double
    let category: String?
}

enum CSVImporter {

    // MARK: - Public

    static func parse(url: URL) -> [ParsedTransaction] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = raw.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        // Detect header row and column indices
        let header = splitCSVLine(lines[0]).map { $0.lowercased() }
        guard let dateIdx = header.firstIndex(where: { $0.contains("date") }),
              let descIdx = header.firstIndex(where: { $0.contains("desc") || $0.contains("memo") || $0.contains("name") || $0.contains("payee") })
        else { return [] }

        // Amount: prefer a combined "amount" column; fall back to debit/credit pair
        let amtIdx    = header.firstIndex(where: { $0 == "amount" || $0 == "transaction amount" })
        let debitIdx  = header.firstIndex(where: { $0.contains("debit")  || $0.contains("withdrawal") })
        let creditIdx = header.firstIndex(where: { $0.contains("credit") || $0.contains("deposit") })

        var results: [ParsedTransaction] = []

        for line in lines.dropFirst() {
            let cols = splitCSVLine(line)
            guard cols.count > max(dateIdx, descIdx) else { continue }

            guard let date = parseDate(cols[dateIdx]) else { continue }

            let desc = cols[descIdx].trimmingCharacters(in: .whitespaces)
            guard !desc.isEmpty else { continue }

            let amount: Double
            if let idx = amtIdx, idx < cols.count {
                guard let v = parseAmount(cols[idx]) else { continue }
                amount = abs(v)
            } else if let di = debitIdx, let ci = creditIdx,
                      di < cols.count, ci < cols.count {
                // Only import debit/withdrawal rows — credit rows are deposits (paychecks, etc.)
                let debit  = parseAmount(cols[di]) ?? 0
                let credit = parseAmount(cols[ci]) ?? 0
                if debit > 0 {
                    amount = debit
                } else if credit > 0 {
                    // Treat credit-only rows as income so the import view can skip them
                    results.append(ParsedTransaction(date: date, description: desc, amount: credit, category: "Income"))
                    continue
                } else {
                    continue
                }
            } else {
                continue
            }

            results.append(ParsedTransaction(
                date: date,
                description: desc,
                amount: amount,
                category: guessCategory(desc)
            ))
        }
        return results
    }

    // MARK: - CSV line splitter (handles quoted fields)

    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Date parsing

    private static func parseDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let formats = ["MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy",
                       "yyyy-MM-dd", "MM-dd-yyyy", "MMM dd, yyyy", "dd MMM yyyy"]
        for fmt in formats {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let d = f.date(from: trimmed) { return d }
        }
        return nil
    }

    // MARK: - Amount parsing

    private static func parseAmount(_ s: String) -> Double? {
        let cleaned = s.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    // MARK: - Category

    static func guessCategory(_ desc: String) -> String {
        let d = desc.lowercased()
        // Paycheck / direct deposit — must come first so it's never mis-categorised as spending
        if d.contains("direct dep") || d.contains("directdep") || d.contains("payroll") ||
           d.contains("paycheck") || d.contains("salary") || d.contains("wages") ||
           d.contains("ach credit") || d.contains("dda credit") || d.contains("deposit") { return "Income" }
        if d.contains("restaurant") || d.contains("mcdonald") || d.contains("starbucks") ||
           d.contains("pizza") || d.contains("cafe") || d.contains("doordash") ||
           d.contains("grubhub") || d.contains("chipotle") || d.contains("subway") ||
           d.contains("jamba") || d.contains("chick-fil") { return "Food & Dining" }
        if d.contains("uber") || d.contains("lyft") || d.contains("gas") || d.contains("shell") ||
           d.contains("exxon") || d.contains("chevron") || d.contains("parking") { return "Transportation" }
        if d.contains("amazon") || d.contains("walmart") || d.contains("target") ||
           d.contains("costco") || d.contains("best buy") || d.contains("ebay") { return "Shopping" }
        if d.contains("netflix") || d.contains("spotify") || d.contains("hulu") ||
           d.contains("disney") || d.contains("apple.com/bill") || d.contains("youtube") ||
           d.contains("steam") || d.contains("playstation") || d.contains("adobe") { return "Subscriptions" }
        if d.contains("gym") || d.contains("fitness") || d.contains("cvs") ||
           d.contains("walgreen") || d.contains("pharmacy") { return "Fitness" }
        if d.contains("hotel") || d.contains("airbnb") || d.contains("airline") ||
           d.contains("flight") || d.contains("cinemark") { return "Entertainment" }
        if d.contains("zelle") || d.contains("venmo") { return "Miscellaneous" }
        return "Miscellaneous"
    }
}
