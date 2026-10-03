import SwiftUI
import Charts

private let spendingCategories: [(group: String, options: [String])] = [
    ("Essentials", ["Food & Dining", "Transportation", "Vehicle"]),
    ("Lifestyle", ["Shopping", "Entertainment", "Tech & Gadgets", "Hobbies"]),
    ("Health", ["Fitness", "Medical", "Personal Care"]),
    ("Home", ["Household", "Home Improvement"]),
    ("Other", ["Travel", "Gifts & Donations", "Subscriptions", "Gaming", "Miscellaneous"])
]

struct SpendingView: View {
    @State private var transactions: [Transaction] = []
    @State private var accounts: [Account] = []
    @State private var subscriptions: [Subscription] = []
    @State private var comparison: MonthlyComparison?
    @State private var isLoading = true
    @State private var showAddForm = false
    @State private var editingTransaction: Transaction?

    private var balanceTotal: Double {
        totalLiveBalance(accounts, transactions: transactions, subscriptions: subscriptions)
    }
    private var chartData: [(month: String, total: Double)] {
        (comparison?.months ?? []).map { ($0.month, $0.total) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    // Balance summary
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Balance").font(.caption).foregroundStyle(.secondary)
                            Text(formatCurrency(balanceTotal)).font(.title.weight(.bold))
                        }
                        .padding(.vertical, 4)
                    }

                    // Monthly trend chart
                    Section("Monthly Trend") {
                        if chartData.isEmpty {
                            Text("No spending data yet.").foregroundStyle(.secondary).font(.footnote)
                        } else {
                            Chart(chartData, id: \.month) { item in
                                LineMark(x: .value("Month", item.month), y: .value("Total", item.total))
                                    .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.31))
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                PointMark(x: .value("Month", item.month), y: .value("Total", item.total))
                                    .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.31))
                            }
                            .frame(height: 200)
                        }
                    }

                    // Transactions
                    Section {
                        ForEach(transactions) { txn in
                            TransactionRow(txn: txn, accounts: accounts, onEdit: { editingTransaction = txn })
                        }
                        .onDelete { offsets in
                            Task { for i in offsets { try? await TransactionsAPI.remove(id: transactions[i].id) }; await load() }
                        }
                        Button { showAddForm = true } label: { Label("Log Spending", systemImage: "plus") }
                    } header: { Text("Recent Transactions") }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddForm) { TransactionFormSheet(accounts: accounts, onSave: { await load() }) }
        .sheet(item: $editingTransaction) { txn in TransactionFormSheet(editing: txn, accounts: accounts, onSave: { await load() }) }
    }

    func load() async {
        async let t = try? TransactionsAPI.list()
        async let m = try? SummaryAPI.monthly(months: 6)
        async let a = try? AccountsAPI.list()
        async let s = try? SubscriptionsAPI.list()
        let (txns, monthly, accts, subs) = await (t, m, a, s)
        transactions = txns ?? []
        comparison = monthly
        accounts = accts ?? []
        subscriptions = subs ?? []
        isLoading = false
    }
}

private struct TransactionRow: View {
    let txn: Transaction
    let accounts: [Account]
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.description).font(.subheadline)
                HStack(spacing: 4) {
                    Text(accounts.first { $0.id == txn.accountId }?.nickname ?? "—")
                    if let cat = txn.category { Text("· \(cat)") }
                }
                .font(.caption).foregroundStyle(.secondary)
                Text(txn.date).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCurrency(txn.amount)).font(.subheadline.weight(.medium))
            Button("Edit", action: onEdit).font(.footnote).foregroundStyle(.accentColor)
        }
    }
}

// MARK: - Transaction Form Sheet

struct TransactionFormSheet: View {
    var editing: Transaction? = nil
    let accounts: [Account]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedAccount: Account?
    @State private var description = ""
    @State private var amount = ""
    @State private var category = spendingCategories[0].options[0]
    @State private var date = Date()
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                if let err = error { Text(err).foregroundStyle(.red).font(.footnote) }
                Section {
                    Picker("Account", selection: $selectedAccount) {
                        ForEach(accounts) { a in Text(a.nickname).tag(Optional(a)) }
                    }
                    TextField("Description (e.g. Groceries)", text: $description)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(spendingCategories, id: \.group) { group in
                            Section(header: Text(group.group)) {
                                ForEach(group.options, id: \.self) { opt in Text(opt).tag(opt) }
                            }
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(editing != nil ? "Edit Transaction" : "Log Spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .onAppear {
                selectedAccount = accounts.first
                if let t = editing {
                    selectedAccount = accounts.first { $0.id == t.accountId }
                    description = t.description; amount = String(t.amount)
                    category = t.category ?? spendingCategories[0].options[0]
                    date = parseISODate(t.date) ?? Date()
                }
            }
        }
    }

    private func save() async {
        error = nil
        let trimDesc = description.trimmingCharacters(in: .whitespaces)
        let amt = Double(amount)
        if trimDesc.isEmpty || amt == nil { error = "Description and amount are required."; return }
        guard let acct = selectedAccount else { error = "Add an account first."; return }
        let input = TransactionInput(accountId: acct.id, description: trimDesc, amount: amt!, category: category, date: formatISODate(date))
        isSaving = true
        do {
            if let t = editing { _ = try await TransactionsAPI.update(id: t.id, input) }
            else { _ = try await TransactionsAPI.create(input) }
            await onSave(); dismiss()
        } catch { self.error = error.localizedDescription }
        isSaving = false
    }
}
