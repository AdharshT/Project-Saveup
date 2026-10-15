import Foundation

enum ClaudeReportAPI {

    // MARK: - Private request/response types

    private struct ClaudeMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ThinkingParam: Encodable {
        let type: String
    }

    private struct ClaudeRequest: Encodable {
        let model: String
        let maxTokens: Int
        let thinking: ThinkingParam
        let messages: [ClaudeMessage]

        enum CodingKeys: String, CodingKey {
            case model, messages, thinking
            case maxTokens = "max_tokens"
        }
    }

    private struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    private struct ClaudeResponse: Decodable {
        let content: [ContentBlock]
    }

    // MARK: - Public

    static func generateReport(
        apiKey: String,
        transactions: [Transaction],
        accounts: [Account],
        subscriptions: [Subscription],
        incomes: [Income],
        comparison: MonthlyComparison?
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw APIError.serverError("No API key provided.")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = ClaudeRequest(
            model: "claude-opus-4-8",
            maxTokens: 2048,
            thinking: ThinkingParam(type: "adaptive"),
            messages: [ClaudeMessage(role: "user", content: buildPrompt(
                transactions: transactions,
                accounts: accounts,
                subscriptions: subscriptions,
                incomes: incomes,
                comparison: comparison
            ))]
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Claude API error \(http.statusCode)"
            throw APIError.serverError(msg)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }.joined(separator: "\n")
        return text.isEmpty ? "No report was generated." : text
    }

    // MARK: - Prompt builder

    private static func buildPrompt(
        transactions: [Transaction],
        accounts: [Account],
        subscriptions: [Subscription],
        incomes: [Income],
        comparison: MonthlyComparison?
    ) -> String {
        var lines: [String] = [
            "You are a personal finance advisor. Analyze the data below and write a concise report.",
            ""
        ]

        if !accounts.isEmpty {
            lines.append("## Account Balances")
            for a in accounts { lines.append("- \(a.nickname): \(formatCurrency(a.balance))") }
            lines.append("")
        }

        let activeIncomes = incomes.filter { $0.active }
        if !activeIncomes.isEmpty {
            lines.append("## Income Sources")
            for inc in activeIncomes {
                let monthly: Double = switch inc.frequency {
                    case .weekly:      inc.amount * 4.33
                    case .biweekly:    inc.amount * 2.17
                    case .semimonthly: inc.amount * 2
                    case .monthly:     inc.amount
                }
                lines.append("- \(inc.source): \(formatCurrency(inc.amount)) (\(inc.frequency.displayName)) ≈ \(formatCurrency(monthly))/month")
            }
            lines.append("")
        }

        if let months = comparison?.months, !months.isEmpty {
            lines.append("## Monthly Spending Trend")
            for m in months.suffix(6) { lines.append("- \(m.month): \(formatCurrency(m.total))") }
            lines.append("")
        }

        // Spending by category — last 90 days
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let recent = transactions.filter { (dateFmt.date(from: $0.date) ?? .distantPast) >= cutoff }
        if !recent.isEmpty {
            var byCategory: [String: Double] = [:]
            for t in recent { byCategory[t.category ?? "Miscellaneous", default: 0] += t.amount }
            lines.append("## Top Spending Categories (Last 90 Days)")
            for (cat, total) in byCategory.sorted(by: { $0.value > $1.value }).prefix(10) {
                lines.append("- \(cat): \(formatCurrency(total))")
            }
            lines.append("")
        }

        let activeSubs = subscriptions.filter { $0.active }
        if !activeSubs.isEmpty {
            let monthlyTotal = activeSubs.reduce(0.0) { sum, s in
                switch s.billingCycle {
                case .weekly:    sum + s.amount * 4.33
                case .monthly:   sum + s.amount
                case .quarterly: sum + s.amount / 3
                case .yearly:    sum + s.amount / 12
                }
            }
            lines.append("## Active Subscriptions (≈\(formatCurrency(monthlyTotal))/month total)")
            for s in activeSubs { lines.append("- \(s.name): \(formatCurrency(s.amount)) (\(s.billingCycle.displayName))") }
            lines.append("")
        }

        lines += [
            "Please provide:",
            "1. A 2–3 sentence financial health summary",
            "2. The top 3 spending observations",
            "3. Two or three specific, actionable recommendations",
            "Use plain text only. Keep it concise and practical."
        ]

        return lines.joined(separator: "\n")
    }
}
