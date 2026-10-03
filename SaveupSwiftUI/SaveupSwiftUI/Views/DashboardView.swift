import SwiftUI
import Charts

@MainActor
final class DashboardStore: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var incomes: [Income] = []
    @Published var nextPaychecks: [NextPaycheck] = []
    @Published var transactions: [Transaction] = []
    @Published var accounts: [Account] = []
    @Published var comparison: MonthlyComparison?
    @Published var isLoading = false
    private var hasLoaded = false

    func loadAll(selectedAccountId: Int? = nil) async {
        if !hasLoaded { isLoading = true }
        async let subs = try? SubscriptionsAPI.list()
        async let inc = try? IncomesAPI.list()
        async let next = try? IncomesAPI.next()
        async let txns = try? TransactionsAPI.list()
        async let accts = try? AccountsAPI.list()
        let (s, i, n, t, a) = await (subs, inc, next, txns, accts)
        subscriptions = s ?? []
        incomes = i ?? []
        nextPaychecks = n ?? []
        transactions = t ?? []
        accounts = a ?? []
        try? await loadComparison(selectedAccountId: selectedAccountId)
        isLoading = false
        hasLoaded = true
    }

    func loadComparison(selectedAccountId: Int? = nil) async throws {
        comparison = try await SummaryAPI.monthly(months: 6, accountId: selectedAccountId)
    }
}

struct DashboardView: View {
    @EnvironmentObject var auth: AuthManager
    @ObservedObject var store: DashboardStore
    @State private var selectedAccountId: Int? = nil
    @State private var expandedCards: Set<String> = []
    @State private var welcomeMessage: String?

    // MARK: Scoped data

    private var scopedSubscriptions: [Subscription] {
        guard let id = selectedAccountId else { return store.subscriptions }
        return store.subscriptions.filter { $0.accountId == id }
    }
    private var scopedIncomes: [Income] {
        guard let id = selectedAccountId else { return store.incomes }
        return store.incomes.filter { $0.accountId == id }
    }
    private var scopedTransactions: [Transaction] {
        guard let id = selectedAccountId else { return store.transactions }
        return store.transactions.filter { $0.accountId == id }
    }
    private var scopedNextPaychecks: [NextPaycheck] {
        guard let id = selectedAccountId else { return store.nextPaychecks }
        return store.nextPaychecks.filter { $0.accountId == id }
    }
    private var selectedAccount: Account? {
        guard let id = selectedAccountId else { return nil }
        return store.accounts.first { $0.id == id }
    }

    // MARK: Computed stats

    private var balanceTotal: Double {
        if let a = selectedAccount {
            return liveAccountBalance(a, transactions: store.transactions, subscriptions: store.subscriptions)
        }
        return totalLiveBalance(store.accounts, transactions: store.transactions, subscriptions: store.subscriptions)
    }
    private var activeIncomes: [Income] { scopedIncomes.filter { $0.active } }
    private var monthlyIncomeTotal: Double {
        activeIncomes.reduce(0) { $0 + monthlyEquivalent(effectiveIncomeAmount($1), cycle: $1.frequency.rawValue) }
    }
    private var activeSubscriptions: [Subscription] { scopedSubscriptions.filter { $0.active } }
    private var monthlySubscriptionTotal: Double {
        activeSubscriptions.reduce(0) { $0 + monthlyEquivalent($1.amount, cycle: $1.billingCycle.rawValue) }
    }
    private var thisMonth: MonthlyTotal? { store.comparison?.months.last }
    private var lastMonth: MonthlyTotal? {
        guard let months = store.comparison?.months, months.count >= 2 else { return nil }
        return months[months.count - 2]
    }
    private var currentMonthStr: String {
        thisMonth?.month ?? String(todayISOString().prefix(7))
    }
    private var dueThisMonthTotal: Double {
        activeSubscriptions.reduce(0) {
            $0 + amountDueInMonth($1.amount, cycle: $1.billingCycle.rawValue,
                                  nextBillingDate: $1.nextBillingDate, monthStr: currentMonthStr)
        }
    }
    private var chartData: [(month: String, total: Double)] {
        (store.comparison?.months ?? []).map { ($0.month, $0.total) }
    }

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading dashboard...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                dashboardContent
            }
        }
        .task { await store.loadAll(selectedAccountId: selectedAccountId) }
    }

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let msg = welcomeMessage {
                    HStack {
                        Text(msg).font(.subheadline.weight(.medium))
                        Spacer()
                        Button { welcomeMessage = nil } label: {
                            Image(systemName: "xmark").imageScale(.small)
                        }
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                }

                if !store.accounts.isEmpty {
                    Picker("Account", selection: $selectedAccountId) {
                        Text("All Accounts").tag(Optional<Int>(nil))
                        ForEach(store.accounts) { a in
                            Text(a.nickname).tag(Optional(a.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedAccountId) { _, _ in
                        Task { try? await store.loadComparison(selectedAccountId: selectedAccountId) }
                    }
                }

                Text("Your financial snapshot — balance, income, subscriptions, and spending all in one place.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Summary cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    SummaryCard(
                        title: selectedAccount.map { "\($0.nickname) Balance" } ?? "Total Balance",
                        stat: formatCurrency(balanceTotal),
                        items: accountCardItems,
                        isExpanded: expandedCards.contains("balance"),
                        onToggle: { toggleCard("balance") }
                    )
                    SummaryCard(
                        title: "Monthly Income",
                        stat: formatCurrency(monthlyIncomeTotal),
                        items: incomeCardItems,
                        isExpanded: expandedCards.contains("income"),
                        onToggle: { toggleCard("income") }
                    )
                    SummaryCard(
                        title: "Monthly Subscriptions",
                        stat: formatCurrency(monthlySubscriptionTotal),
                        items: subscriptionCardItems,
                        expandedHeader: dueThisMonthText,
                        isExpanded: expandedCards.contains("subscriptions"),
                        onToggle: { toggleCard("subscriptions") }
                    )
                    SummaryCard(
                        title: "Spending This Month",
                        stat: formatCurrency(thisMonth?.total ?? 0),
                        items: spendingCardItems,
                        expandedHeader: spendDeltaText,
                        isExpanded: expandedCards.contains("spending"),
                        onToggle: { toggleCard("spending") }
                    )
                    SummaryCard(
                        title: "Next Paycheck",
                        stat: scopedNextPaychecks.first.map { formatCurrency($0.amount) } ?? "—",
                        emptyText: "No income sources yet",
                        items: paycheckCardItems,
                        isExpanded: expandedCards.contains("paycheck"),
                        onToggle: { toggleCard("paycheck") }
                    )
                }

                // Bar chart
                GroupBox("Spending by Month") {
                    if chartData.isEmpty {
                        Text("No spending data yet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Chart(chartData, id: \.month) { item in
                            BarMark(x: .value("Month", item.month), y: .value("Total", item.total))
                                .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.31))
                                .cornerRadius(4)
                        }
                        .chartXAxis { AxisMarks(values: .automatic) { _ in AxisValueLabel() } }
                        .frame(height: 220)
                    }
                }

                // Pie charts
                SavingsPieCard(
                    title: "Savings Breakdown — This Month",
                    income: monthlyIncomeTotal,
                    subscriptionCost: monthlySubscriptionTotal,
                    spending: thisMonth?.total ?? 0,
                    hasData: thisMonth != nil
                )
                SavingsPieCard(
                    title: "Savings Breakdown — Last Month",
                    income: monthlyIncomeTotal,
                    subscriptionCost: monthlySubscriptionTotal,
                    spending: lastMonth?.total ?? 0,
                    hasData: lastMonth != nil
                )
            }
            .padding()
        }
    }

    // MARK: Card item helpers

    private var accountCardItems: [(label: String, value: String)] {
        guard selectedAccount == nil else { return [] }
        return store.accounts.map { a in
            (a.nickname, formatCurrency(liveAccountBalance(a, transactions: store.transactions, subscriptions: store.subscriptions)))
        }
    }
    private var incomeCardItems: [(label: String, value: String)] {
        activeIncomes.map { i in
            (i.source, "\(formatCurrency(monthlyEquivalent(effectiveIncomeAmount(i), cycle: i.frequency.rawValue)))/mo")
        }
    }
    private var subscriptionCardItems: [(label: String, value: String)] {
        activeSubscriptions.map { s in
            (s.name, "\(formatCurrency(s.amount)) \(s.billingCycle.rawValue) · next \(s.nextBillingDate)")
        }
    }
    private var dueThisMonthText: String? {
        activeSubscriptions.isEmpty ? nil : "Billed this month: \(formatCurrency(dueThisMonthTotal))"
    }
    private var spendingCardItems: [(label: String, value: String)] {
        let thisMonthTxns = thisMonth.map { tm in
            scopedTransactions.filter { $0.date.prefix(7) == tm.month }
        } ?? []
        return thisMonthTxns.map { t in
            let label = t.category.map { "\(t.description) · \($0)" } ?? t.description
            return (label, "\(formatCurrency(t.amount)) on \(t.date)")
        }
    }
    private var spendDeltaText: String? {
        guard let thisMonth, let lastMonth else { return nil }
        let delta = thisMonth.total - lastMonth.total
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(formatCurrency(delta)) vs last month"
    }
    private var paycheckCardItems: [(label: String, value: String)] {
        scopedNextPaychecks.map { p in (p.source, "\(formatCurrency(p.amount)) on \(p.date)") }
    }

    private func toggleCard(_ key: String) {
        if expandedCards.contains(key) { expandedCards.remove(key) }
        else { expandedCards.insert(key) }
    }
}

// MARK: - SummaryCard

private struct SummaryCard: View {
    let title: String
    let stat: String
    var emptyText: String? = nil
    let items: [(label: String, value: String)]
    var expandedHeader: String? = nil
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(stat).font(.title2.weight(.bold))
                if items.isEmpty, let empty = emptyText {
                    Text(empty).font(.caption).foregroundStyle(.secondary)
                }
                if !items.isEmpty {
                    Button {
                        onToggle()
                    } label: {
                        Text("\(items.count) active — \(isExpanded ? "hide" : "view all")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                if isExpanded {
                    if let header = expandedHeader {
                        Text(header).font(.caption.weight(.medium))
                    }
                    Divider()
                    ForEach(items, id: \.label) { item in
                        HStack {
                            Text(item.label).font(.caption)
                            Spacer()
                            Text(item.value).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } label: {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .onTapGesture { if !items.isEmpty { onToggle() } }
    }
}

// MARK: - SavingsPieCard

private struct PieSlice: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

private struct SavingsPieCard: View {
    let title: String
    let income: Double
    let subscriptionCost: Double
    let spending: Double
    let hasData: Bool

    private var savingsRaw: Double { income - subscriptionCost - spending }
    private var savings: Double { max(savingsRaw, 0) }
    private var slices: [PieSlice] {
        [
            PieSlice(name: "Savings", value: savings, color: Color(red: 0.16, green: 0.47, blue: 0.84)),
            PieSlice(name: "Subscriptions", value: subscriptionCost, color: Color(red: 0.92, green: 0.41, blue: 0.2)),
            PieSlice(name: "Spending", value: spending, color: Color(red: 0.11, green: 0.69, blue: 0.48))
        ].filter { $0.value > 0 }
    }
    private var total: Double { slices.reduce(0) { $0 + $1.value } }

    var body: some View {
        GroupBox(title) {
            if !hasData || total <= 0 {
                Text("Not enough data yet to show this breakdown.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    if savingsRaw < 0 {
                        Text("You've spent \(formatCurrency(-savingsRaw)) more than you've saved.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Amount", slice.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(slice.color)
                    }
                    .frame(height: 200)

                    ForEach(slices) { slice in
                        HStack {
                            RoundedRectangle(cornerRadius: 3).fill(slice.color)
                                .frame(width: 12, height: 12)
                            Text(slice.name).font(.caption)
                            Spacer()
                            Text("\(formatCurrency(slice.value)) · \(Int(slice.value / total * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
