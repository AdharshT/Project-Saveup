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
    @State private var incomes: [Income] = []
    @State private var comparison: MonthlyComparison?
    @State private var isLoading = true
    @State private var showAddForm = false
    @State private var showImportCSV = false
    @State private var editingTransaction: Transaction?

    // Selection / bulk-delete state
    @State private var isSelecting = false
    @State private var selectedIDs: Set<Int> = []
    @State private var showDeleteSelectedConfirm = false
    @State private var showDeleteAllConfirm = false
    @State private var isDeleting = false

    private var balanceTotal: Double {
        totalLiveBalance(accounts, transactions: transactions, subscriptions: subscriptions, incomes: incomes)
    }
    private var chartData: [(month: String, total: Double)] {
        (comparison?.months ?? []).map { ($0.month, $0.total) }
    }
    private var allSelected: Bool { selectedIDs.count == transactions.count && !transactions.isEmpty }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    // Balance summary + quick actions
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Balance").font(.caption).foregroundStyle(.secondary)
                            Text(formatCurrency(balanceTotal)).font(.title.weight(.bold))
                        }
                        .padding(.vertical, 4)

                        if !isSelecting {
                            HStack(spacing: 12) {
                                Button { showAddForm = true } label: {
                                    Label("Log Spending", systemImage: "plus")
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Color(red: 0.18, green: 0.48, blue: 0.31))

                                Button { showImportCSV = true } label: {
                                    Label("Import CSV", systemImage: "tablecells")
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Color(red: 0.18, green: 0.48, blue: 0.31))
                            }
                            .padding(.vertical, 4)
                        }
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
                            if isSelecting {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedIDs.contains(txn.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(txn.id) ? .red : .secondary)
                                        .font(.title3)
                                    TransactionRow(txn: txn, accounts: accounts, onEdit: {})
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { toggleSelection(txn.id) }
                            } else {
                                TransactionRow(txn: txn, accounts: accounts, onEdit: { editingTransaction = txn })
                            }
                        }
                        .onDelete { offsets in
                            guard !isSelecting else { return }
                            Task { for i in offsets { try? await TransactionsAPI.remove(id: transactions[i].id) }; await load() }
                        }

                    } header: {
                        if isSelecting {
                            HStack {
                                Text("\(transactions.count) transactions")
                                Spacer()
                                Button(allSelected ? "Deselect All" : "Select All") {
                                    if allSelected { selectedIDs = [] }
                                    else { selectedIDs = Set(transactions.map(\.id)) }
                                }
                                .font(.caption).buttonStyle(.borderless)
                            }
                        } else {
                            Text("Recent Transactions")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                // Bottom delete bar shown while selecting
                .safeAreaInset(edge: .bottom) {
                    if isSelecting {
                        deleteBar
                    }
                }
            }
        }
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if transactions.isEmpty {
                    EmptyView()
                } else if isSelecting {
                    Button("Done") { isSelecting = false; selectedIDs = [] }
                } else {
                    Button("Select") { isSelecting = true }
                }
            }
        }
        .sheet(isPresented: $showAddForm) { TransactionFormSheet(accounts: accounts, onSave: { await load() }) }
        .sheet(isPresented: $showImportCSV) { ImportTransactionsView(accounts: accounts, onImport: { await load() }) }
        .sheet(item: $editingTransaction) { txn in TransactionFormSheet(editing: txn, accounts: accounts, onSave: { await load() }) }
        .alert("Delete \(selectedIDs.count) Transaction\(selectedIDs.count == 1 ? "" : "s")?",
               isPresented: $showDeleteSelectedConfirm) {
            Button("Delete", role: .destructive) { Task { await deleteSelected() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .alert("Delete All \(transactions.count) Transactions?",
               isPresented: $showDeleteAllConfirm) {
            Button("Delete All", role: .destructive) { Task { await deleteAll() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will permanently remove every spending log.") }
    }

    // MARK: - Delete bar

    private var deleteBar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                Label("Delete All", systemImage: "trash.fill")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(transactions.isEmpty || isDeleting)

            Button(role: .destructive) {
                showDeleteSelectedConfirm = true
            } label: {
                if isDeleting {
                    ProgressView()
                } else {
                    Label("Delete (\(selectedIDs.count))", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedIDs.isEmpty || isDeleting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func toggleSelection(_ id: Int) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func deleteSelected() async {
        isDeleting = true
        let ids = selectedIDs
        for id in ids { try? await TransactionsAPI.remove(id: id) }
        selectedIDs = []
        isSelecting = false
        isDeleting = false
        await load()
    }

    private func deleteAll() async {
        isDeleting = true
        for txn in transactions { try? await TransactionsAPI.remove(id: txn.id) }
        selectedIDs = []
        isSelecting = false
        isDeleting = false
        await load()
    }

    func load() async {
        async let t = try? TransactionsAPI.list()
        async let m = try? SummaryAPI.monthly(months: 6)
        async let a = try? AccountsAPI.list()
        async let s = try? SubscriptionsAPI.list()
        async let i = try? IncomesAPI.list()
        let (txns, monthly, accts, subs, inc) = await (t, m, a, s, i)
        transactions = txns ?? []
        comparison = monthly
        accounts = accts ?? []
        subscriptions = subs ?? []
        incomes = inc ?? []
        isLoading = false
    }
}

private struct TransactionRow: View {
    let txn: Transaction
    let accounts: [Account]
    let onEdit: (() -> Void)?

    init(txn: Transaction, accounts: [Account], onEdit: (() -> Void)? = nil) {
        self.txn = txn; self.accounts = accounts; self.onEdit = onEdit
    }

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
            if let onEdit {
                Button("Edit", action: onEdit)
                    .font(.footnote).foregroundStyle(Color.accentColor)
                    .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Transaction Form Sheet

struct TransactionFormSheet: View {
    var editing: Transaction? = nil
    let accounts: [Account]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedAccountId: Int = -1
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
                Section("Account") {
                    ForEach(accounts) { a in
                        HStack {
                            Text(a.nickname).foregroundStyle(.primary)
                            Spacer()
                            if selectedAccountId == a.id {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedAccountId = a.id }
                    }
                }
                Section {
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
                selectedAccountId = editing?.accountId ?? accounts.first?.id ?? -1
                if let t = editing {
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
        guard let acct = accounts.first(where: { $0.id == selectedAccountId }) ?? accounts.first else { error = "Add an account first."; return }
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
