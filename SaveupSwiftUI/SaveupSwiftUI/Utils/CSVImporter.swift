import Foundation
import PDFKit

struct ParsedTransaction: Identifiable {
    let id = UUID()
    let date: Date
    let description: String
    let amount: Double
    let category: String?
}

enum PDFImporter {

    // MARK: - Public entry point

    static func parse(url: URL) -> [ParsedTransaction] {
        guard let doc = PDFDocument(url: url) else { return [] }
        let text = (0..<doc.pageCount)
            .compactMap { doc.page(at: $0)?.string }
            .joined(separator: "\n")

        // Try both strategies and return whichever finds more
        let singleLine = parseSingleLine(text)
        let multiLine  = parseMultiLine(text)
        return singleLine.count >= multiLine.count ? singleLine : multiLine
    }

    // MARK: - Strategy 1: single-line "date desc amount"

    private static func parseSingleLine(_ text: String) -> [ParsedTransaction] {
        let lines = cleanLines(text)
        let pattern = try! NSRegularExpression(
            pattern: #"^(\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?)\s{1,6}(.{2,60}?)\s{1,10}(-?\$?[\d,]+\.\d{2})(?:\s+.*)?$"#
        )
        return lines.compactMap { line -> ParsedTransaction? in
            let ns = line as NSString
            guard let m  = pattern.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
                  let dr = Range(m.range(at: 1), in: line),
                  let xr = Range(m.range(at: 2), in: line),
                  let ar = Range(m.range(at: 3), in: line) else { return nil }

            let desc   = String(line[xr]).trimmingCharacters(in: .whitespaces)
            let amtStr = String(line[ar]).replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")

            guard let date   = parseDate(String(line[dr])),
                  let amount = Double(amtStr),
                  amount != 0, !isSummaryLine(desc) else { return nil }

            return ParsedTransaction(date: date, description: desc, amount: abs(amount), category: guessCategory(desc))
        }
    }

    // MARK: - Strategy 2: state-machine for multi-line layouts

    private static func parseMultiLine(_ text: String) -> [ParsedTransaction] {
        let lines = cleanLines(text)
        var results: [ParsedTransaction] = []

        var pendingDate: Date?
        var pendingDesc = ""

        for line in lines {
            // Does this line begin with a date?
            if let date = leadingDate(of: line) {
                // Flush any incomplete pending transaction
                pendingDate = date
                pendingDesc = textAfterLeadingDate(of: line)

                // Check if an amount also appears on the same line
                if let amount = trailingAmount(of: line), amount != 0 {
                    let desc = pendingDesc.isEmpty ? line : pendingDesc
                    if !isSummaryLine(desc) {
                        results.append(ParsedTransaction(date: date, description: clean(desc), amount: abs(amount), category: guessCategory(desc)))
                    }
                    pendingDate = nil; pendingDesc = ""
                }
            } else if let date = pendingDate {
                // We're inside a pending transaction — look for the amount
                if let amount = trailingAmount(of: line), amount != 0 {
                    let desc = pendingDesc.isEmpty ? line : pendingDesc
                    if !isSummaryLine(desc) {
                        results.append(ParsedTransaction(date: date, description: clean(desc), amount: abs(amount), category: guessCategory(desc)))
                    }
                    pendingDate = nil; pendingDesc = ""
                } else if pendingDesc.isEmpty {
                    pendingDesc = line  // first line after date = description
                }
            }
        }

        return results
    }

    // MARK: - Helpers

    private static func cleanLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 3 }
    }

    private static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces)
    }

    private static let datePatterns: [String] = [
        "MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy",
        "yyyy-MM-dd", "MM-dd-yyyy", "MMM dd, yyyy"
    ]

    static func parseDate(_ s: String) -> Date? {
        for fmt in datePatterns {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let d = f.date(from: s.trimmingCharacters(in: .whitespaces)) { return d }
        }
        return nil
    }

    // Returns the date if the line STARTS with a date token
    private static func leadingDate(of line: String) -> Date? {
        let dateRx = try! NSRegularExpression(pattern: #"^(\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?)"#)
        let ns = line as NSString
        guard let m = dateRx.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              let r = Range(m.range(at: 1), in: line) else { return nil }
        return parseDate(String(line[r]))
    }

    // Text that comes after the leading date token on the same line
    private static func textAfterLeadingDate(of line: String) -> String {
        let dateRx = try! NSRegularExpression(pattern: #"^\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?\s*"#)
        let ns = line as NSString
        guard let m = dateRx.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return "" }
        let end = m.range.location + m.range.length
        if end >= ns.length { return "" }
        return String(line[line.index(line.startIndex, offsetBy: end)...])
    }

    // Returns the last dollar amount found on a line
    private static func trailingAmount(of line: String) -> Double? {
        let amtRx = try! NSRegularExpression(pattern: #"(-?\$?[\d,]{1,10}\.\d{2})"#)
        let ns = line as NSString
        let matches = amtRx.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last, let r = Range(last.range(at: 1), in: line) else { return nil }
        let s = String(line[r]).replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        return Double(s)
    }

    private static func isSummaryLine(_ s: String) -> Bool {
        let lower = s.lowercased()
        return ["balance", "total", "minimum payment", "credit limit", "new balance",
                "previous balance", "payment due", "amount due"].contains(where: { lower.contains($0) })
    }

    static func guessCategory(_ desc: String) -> String {
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
        if d.contains("electric") || d.contains("water bill") || d.contains("internet") ||
           d.contains("at&t") || d.contains("verizon") || d.contains("comcast") { return "Household" }
        return "Miscellaneous"
    }
}
