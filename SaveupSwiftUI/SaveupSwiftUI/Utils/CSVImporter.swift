import Foundation

struct ParsedTransaction: Identifiable {
    let id = UUID()
    let date: Date
    let description: String
    let amount: Double
    let category: String?
}

enum CSVImporter {

    static func parse(_ content: String) -> [ParsedTransaction] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { return [] }

        let rawHeader = parseRow(lines[0])
        let header = rawHeader.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }
        let dataLines = Array(lines.dropFirst())

        if let r = parseSingleAmountFormat(header: header, lines: dataLines) { return r }
        if let r = parseSplitDebitCreditFormat(header: header, lines: dataLines) { return r }
        return []
    }

    // Chase, BofA, Wells Fargo — single "amount" column, negative = spending
    private static func parseSingleAmountFormat(header: [String], lines: [String]) -> [ParsedTransaction]? {
        guard let dateCol = header.firstIndex(where: { $0.contains("date") }),
              let descCol = header.firstIndex(where: { $0 == "description" || $0 == "payee" || $0 == "memo" || $0 == "name" }),
              let amtCol  = header.firstIndex(where: { $0 == "amount" }) else { return nil }

        return lines.compactMap { line -> ParsedTransaction? in
            let cols = parseRow(line)
            guard cols.count > max(dateCol, descCol, amtCol) else { return nil }
            let dateStr = clean(cols[dateCol])
            let desc    = clean(cols[descCol])
            let amtStr  = clean(cols[amtCol])
            guard let date   = parseDate(dateStr),
                  let amount = parseAmount(amtStr), amount != 0 else { return nil }
            return ParsedTransaction(date: date, description: desc, amount: abs(amount), category: guessCategory(desc))
        }
    }

    // Citi, Capital One — separate "debit" and "credit" columns
    private static func parseSplitDebitCreditFormat(header: [String], lines: [String]) -> [ParsedTransaction]? {
        guard let dateCol  = header.firstIndex(where: { $0.contains("date") }),
              let descCol  = header.firstIndex(where: { $0.contains("description") }),
              let debitCol = header.firstIndex(where: { $0 == "debit" }) else { return nil }

        return lines.compactMap { line -> ParsedTransaction? in
            let cols = parseRow(line)
            guard cols.count > max(dateCol, descCol, debitCol) else { return nil }
            let dateStr  = clean(cols[dateCol])
            let desc     = clean(cols[descCol])
            let debitStr = clean(cols[debitCol])
            guard let date   = parseDate(dateStr),
                  let amount = parseAmount(debitStr), amount > 0 else { return nil }
            return ParsedTransaction(date: date, description: desc, amount: amount, category: guessCategory(desc))
        }
    }

    // MARK: - Row parser (handles quoted fields with commas inside)

    static func parseRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle() }
            else if ch == "," && !inQuotes { fields.append(current); current = "" }
            else { current.append(ch) }
        }
        fields.append(current)
        return fields
    }

    private static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "\" ").union(.whitespaces))
    }

    private static func parseAmount(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: ""))
    }

    private static func parseDate(_ s: String) -> Date? {
        for fmt in ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "dd/MM/yyyy", "MMM dd, yyyy", "MM/dd/yy"] {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    private static func guessCategory(_ desc: String) -> String {
        let d = desc.lowercased()
        if d.contains("restaurant") || d.contains("mcdonald") || d.contains("starbucks") ||
           d.contains("pizza") || d.contains("cafe") || d.contains("doordash") ||
           d.contains("grubhub") || d.contains("chipotle") || d.contains("subway") { return "Food & Dining" }
        if d.contains("uber") || d.contains("lyft") || d.contains("gas") || d.contains("shell") ||
           d.contains("exxon") || d.contains("bp ") || d.contains("chevron") || d.contains("parking") { return "Transportation" }
        if d.contains("amazon") || d.contains("walmart") || d.contains("target") ||
           d.contains("costco") || d.contains("best buy") || d.contains("ebay") { return "Shopping" }
        if d.contains("netflix") || d.contains("spotify") || d.contains("hulu") ||
           d.contains("disney") || d.contains("apple.com/bill") || d.contains("youtube") { return "Subscriptions" }
        if d.contains("gym") || d.contains("fitness") || d.contains("planet") ||
           d.contains("cvs") || d.contains("walgreen") || d.contains("pharmacy") { return "Fitness" }
        if d.contains("hotel") || d.contains("airbnb") || d.contains("airline") ||
           d.contains("flight") || d.contains("expedia") || d.contains("delta") { return "Travel" }
        if d.contains("electric") || d.contains("water") || d.contains("internet") ||
           d.contains("at&t") || d.contains("verizon") || d.contains("comcast") { return "Household" }
        return "Miscellaneous"
    }
}
