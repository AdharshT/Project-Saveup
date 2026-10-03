import SwiftUI

struct IncomeView: View {
    @State private var incomes: [Income] = []
    @State private var nextPaychecks: [NextPaycheck] = []
    @State private var accounts: [Account] = []
    @State private var isLoading = true
    @State private var showAddForm = false
    @State private var editingIncome: Income?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    // Upcoming paychecks
                    Section("Upcoming Paychecks") {
                        if nextPaychecks.isEmpty {
                            Text("No income sources yet.").foregroundStyle(.secondary).font(.footnote)
                        }
                        ForEach(nextPaychecks) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.source).font(.subheadline)
                                    Text(p.date).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(p.amount)).font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    // Income sources
                    Section {
                        ForEach(incomes) { income in
                            IncomeRow(income: income, accounts: accounts, onEdit: { editingIncome = income })
                        }
                        .onDelete { offsets in
                            Task { for i in offsets { try? await IncomesAPI.remove(id: incomes[i].id) }; await load() }
                        }
                        Button { showAddForm = true } label: { Label("Add Income Source", systemImage: "plus") }
                    } header: { Text("All Income Sources") }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddForm) { IncomeFormSheet(accounts: accounts, onSave: { await load() }) }
        .sheet(item: $editingIncome) { income in IncomeFormSheet(editing: income, accounts: accounts, onSave: { await load() }) }
    }

    func load() async {
        async let i = try? IncomesAPI.list()
        async let n = try? IncomesAPI.next()
        async let a = try? AccountsAPI.list()
        let (inc, next, accts) = await (i, n, a)
        incomes = inc ?? []
        nextPaychecks = next ?? []
        accounts = accts ?? []
        isLoading = false
    }
}

private struct IncomeRow: View {
    let income: Income
    let accounts: [Account]
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(income.source).font(.subheadline)
                Text(accounts.first { $0.id == income.accountId }?.nickname ?? "—")
                    .font(.caption).foregroundStyle(.secondary)
                Text(income.frequency.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(effectiveIncomeAmount(income))).font(.subheadline.weight(.medium))
                if income.payType == .hourly, let hrs = income.hoursPerPeriod {
                    Text("(\(formatCurrency(income.amount))/hr × \(String(format: "%.0f", hrs))hr)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text("next: \(income.nextPayDate)").font(.caption).foregroundStyle(.secondary)
            }
            Button("Edit", action: onEdit).font(.footnote).foregroundStyle(.accentColor)
        }
    }
}

// MARK: - Income Form Sheet

struct IncomeFormSheet: View {
    var editing: Income? = nil
    let accounts: [Account]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedAccount: Account?
    @State private var source = ""
    @State private var payType: PayType = .fixed
    @State private var amount = ""
    @State private var hoursPerPeriod = ""
    @State private var frequency: IncomeFrequency = .biweekly
    @State private var nextPayDate = Date()
    @State private var payPeriodStart: Date? = nil
    @State private var payPeriodEnd: Date? = nil
    @State private var active = true
    @State private var error: String?
    @State private var isSaving = false

    private var paycheckPreview: String? {
        guard payType == .hourly,
              let a = Double(amount), a > 0,
              let h = Double(hoursPerPeriod), h > 0 else { return nil }
        return "= \(formatCurrency(a * h)) per paycheck at \(frequency.rawValue) frequency"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let err = error { Text(err).foregroundStyle(.red).font(.footnote) }
                Section {
                    Picker("Account", selection: $selectedAccount) {
                        ForEach(accounts) { a in Text(a.nickname).tag(Optional(a)) }
                    }
                    TextField("Source (e.g. Main Job)", text: $source)
                    Picker("Pay Type", selection: $payType) {
                        ForEach(PayType.allCases) { t in Text(t.displayName).tag(t) }
                    }
                    .onChange(of: payType) { _, _ in hoursPerPeriod = "" }

                    TextField(payType == .hourly ? "Hourly Rate" : "Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    if payType == .hourly {
                        TextField("Hours per Pay Period", text: $hoursPerPeriod)
                            .keyboardType(.decimalPad)
                        if let preview = paycheckPreview {
                            Text(preview).font(.caption).foregroundStyle(.secondary)
                        }
                        DatePicker("Pay Period Start (optional)",
                                   selection: Binding(
                                    get: { payPeriodStart ?? Date() },
                                    set: { payPeriodStart = $0 }
                                   ),
                                   displayedComponents: .date)
                        DatePicker("Pay Period End (optional)",
                                   selection: Binding(
                                    get: { payPeriodEnd ?? Date() },
                                    set: { payPeriodEnd = $0 }
                                   ),
                                   displayedComponents: .date)
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(IncomeFrequency.allCases) { f in Text(f.displayName).tag(f) }
                    }
                    DatePicker("Next Pay Date", selection: $nextPayDate, displayedComponents: .date)
                    Toggle("Active", isOn: $active)
                }
            }
            .navigationTitle(editing != nil ? "Edit Income Source" : "Add Income Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .onAppear {
                selectedAccount = accounts.first
                if let i = editing {
                    selectedAccount = accounts.first { $0.id == i.accountId }
                    source = i.source; payType = i.payType
                    amount = String(i.amount)
                    hoursPerPeriod = i.hoursPerPeriod.map { String($0) } ?? ""
                    frequency = i.frequency
                    nextPayDate = parseISODate(i.nextPayDate) ?? Date()
                    if let s = i.payPeriodStart { payPeriodStart = parseISODate(s) }
                    if let e = i.payPeriodEnd { payPeriodEnd = parseISODate(e) }
                    active = i.active
                }
            }
        }
    }

    private func save() async {
        error = nil
        let trimSource = source.trimmingCharacters(in: .whitespaces)
        let amt = Double(amount)
        if trimSource.isEmpty || amt == nil { error = "Source and amount are required."; return }
        if payType == .hourly && Double(hoursPerPeriod) == nil {
            error = "Hours per pay period is required for hourly pay."; return
        }
        guard let acct = selectedAccount else { error = "Add an account first."; return }
        let input = IncomeInput(
            accountId: acct.id, source: trimSource, amount: amt!,
            frequency: frequency, payType: payType,
            hoursPerPeriod: payType == .hourly ? Double(hoursPerPeriod) : nil,
            payPeriodStart: payType == .hourly ? payPeriodStart.map(formatISODate) : nil,
            payPeriodEnd: payType == .hourly ? payPeriodEnd.map(formatISODate) : nil,
            nextPayDate: formatISODate(nextPayDate), active: active
        )
        isSaving = true
        do {
            if let i = editing { _ = try await IncomesAPI.update(id: i.id, input) }
            else { _ = try await IncomesAPI.create(input) }
            await onSave(); dismiss()
        } catch { self.error = error.localizedDescription }
        isSaving = false
    }
}
