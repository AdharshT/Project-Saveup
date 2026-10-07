import SwiftUI

private let bankPresets = [
    "Chase", "Bank of America", "Wells Fargo", "Citibank",
    "U.S. Bank", "PNC Bank", "Truist", "TD Bank", "Capital One"
]

struct AccountsView: View {
    @State private var accounts: [Account] = []
    @State private var banks: [Bank] = []
    @State private var transactions: [Transaction] = []
    @State private var subscriptions: [Subscription] = []
    @State private var incomes: [Income] = []
    @State private var isLoading = true
    @State private var showAddBank = false
    @State private var showAddAccount = false
    @State private var editingBank: Bank?
    @State private var editingAccount: Account?
    @State private var bankError: String?
    @State private var accountError: String?

    private var totalBalance: Double {
        totalLiveBalance(accounts, transactions: transactions, subscriptions: subscriptions, incomes: incomes)
    }
    private func liveBalance(_ account: Account) -> Double {
        liveAccountBalance(account, transactions: transactions, subscriptions: subscriptions, incomes: incomes)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    // Total balance
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Balance").font(.caption).foregroundStyle(.secondary)
                            Text(formatCurrency(totalBalance)).font(.title.weight(.bold))
                            Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Banks
                    Section {
                        ForEach(banks) { bank in
                            HStack {
                                Text(bank.name)
                                Spacer()
                                Button("Edit") { editingBank = bank }
                                    .font(.footnote).foregroundStyle(Color.accentColor)
                                    .buttonStyle(.borderless)
                            }
                        }
                        .onDelete { offsets in
                            Task { for i in offsets { try? await BanksAPI.remove(id: banks[i].id) }; await load() }
                        }
                        Button { showAddBank = true } label: {
                            Label("Add Bank", systemImage: "plus")
                        }
                    } header: { Text("Banks") }

                    // Accounts
                    Section {
                        ForEach(accounts) { account in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.nickname).font(.subheadline)
                                    if let type = account.type {
                                        Text(type.displayName).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(formatCurrency(liveBalance(account))).font(.subheadline.weight(.medium))
                                Button("Edit") { editingAccount = account }
                                    .font(.footnote).foregroundStyle(Color.accentColor)
                                    .buttonStyle(.borderless)
                            }
                        }
                        .onDelete { offsets in
                            let removedIds = Set(offsets.map { accounts[$0].id })
                            accounts.removeAll { removedIds.contains($0.id) }
                            Task { for id in removedIds { try? await AccountsAPI.remove(id: id) }; await load() }
                        }
                        Button { showAddAccount = true } label: {
                            Label("Add Account", systemImage: "plus")
                        }
                    } header: { Text("Accounts") }
                    .disabled(banks.isEmpty)
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddBank) { BankFormSheet(banks: banks, onSave: { await load() }) }
        .sheet(item: $editingBank) { bank in BankFormSheet(editing: bank, banks: banks, onSave: { await load() }) }
        .sheet(isPresented: $showAddAccount) { AccountFormSheet(banks: banks, onSave: { await load() }) }
        .sheet(item: $editingAccount) { account in AccountFormSheet(editing: account, banks: banks, onSave: { await load() }) }
    }

    func load() async {
        async let a = try? AccountsAPI.list()
        async let b = try? BanksAPI.list()
        async let t = try? TransactionsAPI.list()
        async let s = try? SubscriptionsAPI.list()
        async let i = try? IncomesAPI.list()
        let (accts, bnks, txns, subs, inc) = await (a, b, t, s, i)
        accounts = accts ?? []
        banks = bnks ?? []
        transactions = txns ?? []
        subscriptions = subs ?? []
        incomes = inc ?? []
        isLoading = false
    }
}

// MARK: - Bank Form Sheet

struct BankFormSheet: View {
    var editing: Bank? = nil
    let banks: [Bank]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedPreset = bankPresets[0]
    @State private var customName = ""
    @State private var useCustom = false
    @State private var error: String?
    @State private var isSaving = false

    private var effectiveName: String { useCustom ? customName : selectedPreset }

    var body: some View {
        NavigationStack {
            Form {
                if let err = error { Text(err).foregroundStyle(.red).font(.footnote) }
                Section {
                    Picker("Bank", selection: $selectedPreset) {
                        ForEach(bankPresets, id: \.self) { Text($0) }
                        Text("Other").tag("__other__")
                    }
                    .onChange(of: selectedPreset) { _, v in useCustom = (v == "__other__") }
                    if useCustom {
                        TextField("Custom bank name", text: $customName)
                    }
                }
            }
            .navigationTitle(editing != nil ? "Edit Bank" : "Add Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .onAppear {
                if let b = editing {
                    if bankPresets.contains(b.name) { selectedPreset = b.name }
                    else { useCustom = true; customName = b.name; selectedPreset = "__other__" }
                }
            }
        }
    }

    private func save() async {
        error = nil
        let name = effectiveName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { error = "Bank name is required."; return }
        isSaving = true
        do {
            if let b = editing { _ = try await BanksAPI.update(id: b.id, BankInput(name: name)) }
            else { _ = try await BanksAPI.create(BankInput(name: name)) }
            await onSave()
            dismiss()
        } catch { self.error = error.localizedDescription }
        isSaving = false
    }
}

// MARK: - Account Form Sheet

struct AccountFormSheet: View {
    var editing: Account? = nil
    let banks: [Bank]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedBank: Bank?
    @State private var accountType: AccountType = .checking
    @State private var last4 = ""
    @State private var balance = ""
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                if let err = error { Text(err).foregroundStyle(.red).font(.footnote) }
                Section {
                    Picker("Bank", selection: Binding(
                        get: { selectedBank ?? banks.first ?? Bank(id: 0, name: "", createdAt: "") },
                        set: { selectedBank = $0 }
                    )) {
                        ForEach(banks) { b in Text(b.name).tag(b) }
                    }
                    .pickerStyle(.menu)
                    Picker("Type", selection: $accountType) {
                        ForEach(AccountType.allCases) { t in Text(t.displayName).tag(t) }
                    }
                    TextField("Last 4 digits (optional)", text: $last4)
                        .keyboardType(.numberPad)
                    TextField("Balance", text: $balance)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(editing != nil ? "Edit Account" : "Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .onAppear {
                selectedBank = banks.first
                if let a = editing {
                    selectedBank = banks.first { $0.id == a.bankId }
                    accountType = a.type ?? .checking
                    last4 = a.last4 ?? ""
                    balance = String(a.balance)
                }
            }
        }
    }

    private func save() async {
        error = nil
        guard let bank = selectedBank ?? banks.first else { error = "Add a bank first."; return }
        let bal = Double(balance) ?? 0
        let l4 = last4.trimmingCharacters(in: .whitespaces)
        let nickname = l4.isEmpty ? bank.name : "\(bank.name) ••\(l4)"
        let input = AccountInput(bankId: bank.id, nickname: nickname, type: accountType, last4: l4.isEmpty ? nil : l4, balance: bal)
        isSaving = true
        do {
            if let a = editing { _ = try await AccountsAPI.update(id: a.id, input) }
            else { _ = try await AccountsAPI.create(input) }
            await onSave()
            dismiss()
        } catch { self.error = error.localizedDescription }
        isSaving = false
    }
}

