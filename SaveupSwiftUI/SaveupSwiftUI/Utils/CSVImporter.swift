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

    static func parse(url: URL) -> [ParsedTransaction] {
        guard let doc = PDFDocument(url: url) else { return [] }
        let text = (0..<doc.pageCount)
            .compactMap { doc.page(at: $0)?.string }
            .joined(separator: "\n")
        return extractTransactions(from: text)
    }

    // MARK: - Text extraction

    private static func extractTransactions(from text: String) -> [ParsedTransaction] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 5 }

        // Matches: "01/15/2024 Amazon.com -45.67" or "01/15 Amazon.com 45.67"
        // Trailing group allows optional running balance after the amount
        let pattern = try! NSRegularExpression(
            pattern: #"^(\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?)\s{1,5}(.{2,60}?)\s{1,10}(-?\$?[\d,]+\.\d{2})(?:\s+.*)?$"#
        )

        let skipWords = ["balance", "total", "minimum", "payment due", "credit limit", "new balance", "previous balance"]

        return lines.compactMap { line -> ParsedTransaction? in
            let ns = line as NSString
            guard let match = pattern.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
                  let dateR = Range(match.range(at: 1), in: line),
                  let descR = Range(match.range(at: 2), in: line),
                  let amtR  = Range(match.range(at: 3), in: line) else { return nil }

            let dateStr = String(line[dateR])
            let desc    = String(line[descR]).trimmingCharacters(in: .whitespaces)
            let amtStr  = String(line[amtR])
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")

            guard let date   = parseDate(dateStr),
                  let amount = Double(amtStr),
                  amount != 0,
                  desc.count >= 2 else { return nil }

            let descLower = desc.lowercased()
            if skipWords.contains(where: { descLower.contains($0) }) { return nil }

            return ParsedTransaction(date: date, description: desc, amount: abs(amount), category: guessCategory(desc))
        }
    }

    // MARK: - Helpers

    private static func parseDate(_ s: String) -> Date? {
        for fmt in ["MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy", "yyyy-MM-dd", "MM-dd-yyyy"] {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let d = f.date(from: s) { return d }
        }
        return nil
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
