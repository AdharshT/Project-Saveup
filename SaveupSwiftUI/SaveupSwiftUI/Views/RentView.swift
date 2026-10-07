import SwiftUI

private let housingCategory = "Housing"

struct RentView: View {
    @State private var items: [Subscription] = []
    @State private var accounts: [Account] = []
    @State private var isLoading = true
    @State private var showAddForm = false
    @State private var editingItem: Subscription?

    private var monthlyTotal: Double {
        items.filter { $0.active }.reduce(0) { $0 + monthlyEquivalent($1.amount, cycle: $1.billingCycle.rawValue) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Monthly Housing Cost").font(.caption).foregroundStyle(.secondary)
                            Text(formatCurrency(monthlyTotal)).font(.title.weight(.bold))
                            let active = items.filter { $0.active }.count
                            Text("\(active) active item\(active == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        ForEach(items) { item in
                            RentRow(item: item, accounts: accounts,
                                    onToggle: { Task { try? await toggle(item) } },
                                    onEdit: { editingItem = item })
                        }
                        .onDelete { offsets in
                            Task { for i in offsets { try? await SubscriptionsAPI.remove(id: items[i].id) }; await load() }
                        }
                        Button { showAddForm = true } label: { Label("Add Rent or Utility", systemImage: "plus") }
                    } header: { Text("Rent & Utilities") }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddForm) { RentFormSheet(accounts: accounts, onSave: { await load() }) }
        .sheet(item: $editingItem) { item in RentFormSheet(editing: item, accounts: accounts, onSave: { await load() }) }
    }

    func load() async {
        async let s = try? SubscriptionsAPI.list()
        async let a = try? AccountsAPI.list()
        let (subs, accts) = await (s, a)
        items = (subs ?? []).filter { $0.category == housingCategory }
        accounts = accts ?? []
        isLoading = false
    }

    func toggle(_ item: Subscription) async throws {
        _ = try await SubscriptionsAPI.updateActive(id: item.id, active: !item.active)
        await load()
    }
}

private struct RentRow: View {
    let item: Subscription
    let accounts: [Account]
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).opacity(item.active ? 1 : 0.5)
                Text(accounts.first { $0.id == item.accountId }?.nickname ?? "—")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(item.amount)).font(.subheadline.weight(.medium))
                Text(item.billingCycle.displayName).font(.caption).foregroundStyle(.secondary)
                Text("~\(formatCurrency(monthlyEquivalent(item.amount, cycle: item.billingCycle.rawValue)))/mo")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Toggle("", isOn: Binding(get: { item.active }, set: { _ in onToggle() }))
                .labelsHidden().scaleEffect(0.8)
            Button("Edit", action: onEdit)
                .font(.footnote).foregroundStyle(Color.accentColor)
                .buttonStyle(.borderless)
        }
    }
}

// MARK: - Rent Form Sheet

struct RentFormSheet: View {
    var editing: Subscription? = nil
    @State private var accounts: [Account]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedAccountId: Int = -1

    init(editing: Subscription? = nil, accounts: [Account], onSave: @escaping () async -> Void) {
        self.editing = editing
        self._accounts = State(initialValue: accounts)
        self.onSave = onSave
    }
    @State private var name = ""
    @State private var amount = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var lastPaymentDate = Date()
    @State private var active = true
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                if let err = error { Text(err).foregroundStyle(.red).font(.footnote) }
                Section("Account") {
                    if accounts.isEmpty {
                        Text("Loading accounts…").foregroundStyle(.secondary).font(.footnote)
                    } else {
                        Picker("Account", selection: $selectedAccountId) {
                            ForEach(accounts) { a in
                                Text(a.nickname).tag(a.id)
                            }
                        }
                    }
                }
                Section {
                    TextField("Name (e.g. Rent)", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Billing Cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases) { c in Text(c.displayName).tag(c) }
                    }
                    DatePicker("Last Payment Date", selection: $lastPaymentDate, displayedComponents: .date)
                    Text("Next bill: \(addBillingInterval(formatISODate(lastPaymentDate), cycle: billingCycle.rawValue))")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Active", isOn: $active)
                }
            }
            .navigationTitle(editing != nil ? "Edit Rent or Utility" : "Add Rent or Utility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .task {
                if accounts.isEmpty {
                    accounts = (try? await AccountsAPI.list()) ?? []
                }
                if selectedAccountId == -1 {
                    selectedAccountId = editing?.accountId ?? accounts.first?.id ?? -1
                }
            }
            .onAppear {
                selectedAccountId = editing?.accountId ?? accounts.first?.id ?? -1
                if let i = editing {
                    name = i.name; amount = String(i.amount)
                    billingCycle = i.billingCycle
                    lastPaymentDate = parseISODate(i.lastPaymentDate) ?? Date()
                    active = i.active
                }
            }
        }
    }

    private func save() async {
        error = nil
        let trimName = name.trimmingCharacters(in: .whitespaces)
        let amt = Double(amount)
        if trimName.isEmpty || amt == nil { error = "Name and amount are required."; return }
        guard let acct = accounts.first(where: { $0.id == selectedAccountId }) ?? accounts.first else { error = "Add an account first."; return }
        let input = SubscriptionInput(
            accountId: acct.id, name: trimName, amount: amt!,
            billingCycle: billingCycle, category: housingCategory,
            lastPaymentDate: formatISODate(lastPaymentDate), active: active, notes: nil
        )
        isSaving = true
        do {
            if let i = editing { _ = try await SubscriptionsAPI.update(id: i.id, input) }
            else { _ = try await SubscriptionsAPI.create(input) }
            await onSave(); dismiss()
        } catch { self.error = error.localizedDescription }
        isSaving = false
    }
}
