import SwiftUI

private let subscriptionCategories: [(group: String, options: [String])] = [
    ("Streaming & Media", ["Video", "Music", "Gaming"]),
    ("Productivity", ["Software & Apps", "Cloud Storage"]),
    ("Health & Fitness", ["Gym/Fitness", "Wellness"]),
    ("News & Learning", ["News & Media", "Education"]),
    ("Other", ["Shopping", "Utilities", "Miscellaneous"])
]

private let housingCategory = "Housing"

struct SubscriptionsView: View {
    @State private var subscriptions: [Subscription] = []
    @State private var accounts: [Account] = []
    @State private var isLoading = true
    @State private var showAddForm = false
    @State private var editingSub: Subscription?

    private var activeTotal: Double {
        subscriptions.filter { $0.active }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Total").font(.caption).foregroundStyle(.secondary)
                            Text(formatCurrency(activeTotal)).font(.title.weight(.bold))
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        ForEach(subscriptions) { sub in
                            SubscriptionRow(sub: sub, accounts: accounts,
                                           onToggle: { Task { try? await toggleActive(sub) } },
                                           onEdit: { editingSub = sub })
                        }
                        .onDelete { offsets in
                            Task { for i in offsets { try? await SubscriptionsAPI.remove(id: subscriptions[i].id) }; await load() }
                        }
                        Button { showAddForm = true } label: { Label("Add Subscription", systemImage: "plus") }
                    } header: {
                        HStack { Text("Subscriptions"); Spacer(); Text("Active total: \(formatCurrency(activeTotal))").textCase(nil) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddForm) { SubscriptionFormSheet(accounts: accounts, onSave: { await load() }) }
        .sheet(item: $editingSub) { sub in SubscriptionFormSheet(editing: sub, accounts: accounts, onSave: { await load() }) }
    }

    func load() async {
        async let s = try? SubscriptionsAPI.list()
        async let a = try? AccountsAPI.list()
        let (subs, accts) = await (s, a)
        subscriptions = (subs ?? []).filter { $0.category != housingCategory }
        accounts = accts ?? []
        isLoading = false
    }

    func toggleActive(_ sub: Subscription) async throws {
        _ = try await SubscriptionsAPI.updateActive(id: sub.id, active: !sub.active)
        await load()
    }
}

private struct SubscriptionRow: View {
    let sub: Subscription
    let accounts: [Account]
    let onToggle: () -> Void
    let onEdit: () -> Void

    private var accountName: String { accounts.first { $0.id == sub.accountId }?.nickname ?? "—" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name).font(.subheadline).opacity(sub.active ? 1 : 0.5)
                    Text("\(accountName) · \(sub.billingCycle.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(sub.amount)).font(.subheadline.weight(.medium))
                    Text("next: \(sub.nextBillingDate)").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("", isOn: Binding(get: { sub.active }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .scaleEffect(0.8)
                Button("Edit", action: onEdit).font(.footnote).foregroundStyle(.accentColor)
            }
        }
    }
}

// MARK: - Subscription Form Sheet

struct SubscriptionFormSheet: View {
    var editing: Subscription? = nil
    let accounts: [Account]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedAccount: Account?
    @State private var name = ""
    @State private var amount = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var category = subscriptionCategories[0].options[0]
    @State private var lastPaymentDate = Date()
    @State private var active = true
    @State private var notes = ""
    @State private var error: String?
    @State private var isSaving = false

    private var nextBillPreview: String {
        addBillingInterval(formatISODate(lastPaymentDate), cycle: billingCycle.rawValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let err = error { Text(err).foregroundStyle(.red).font(.footnote) }
                Section {
                    Picker("Account", selection: $selectedAccount) {
                        ForEach(accounts) { a in Text(a.nickname).tag(Optional(a)) }
                    }
                    TextField("Name (e.g. Netflix)", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Billing Cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases) { c in Text(c.displayName).tag(c) }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(subscriptionCategories, id: \.group) { group in
                            Section(header: Text(group.group)) {
                                ForEach(group.options, id: \.self) { opt in Text(opt).tag(opt) }
                            }
                        }
                    }
                    DatePicker("Last Payment Date", selection: $lastPaymentDate, displayedComponents: .date)
                    Text("Next bill: \(nextBillPreview)").font(.caption).foregroundStyle(.secondary)
                    Toggle("Active", isOn: $active)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(editing != nil ? "Edit Subscription" : "Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .onAppear {
                selectedAccount = accounts.first
                if let s = editing {
                    selectedAccount = accounts.first { $0.id == s.accountId }
                    name = s.name
                    amount = String(s.amount)
                    billingCycle = s.billingCycle
                    category = s.category ?? subscriptionCategories[0].options[0]
                    lastPaymentDate = parseISODate(s.lastPaymentDate) ?? Date()
                    active = s.active
                    notes = s.notes ?? ""
                }
            }
        }
    }

    private func save() async {
        error = nil
        let trimName = name.trimmingCharacters(in: .whitespaces)
        let amt = Double(amount)
        if trimName.isEmpty || amt == nil { error = "Name and amount are required."; return }
        guard let acct = selectedAccount else { error = "Add an account first."; return }
        let input = SubscriptionInput(
            accountId: acct.id, name: trimName, amount: amt!,
            billingCycle: billingCycle, category: category,
            lastPaymentDate: formatISODate(lastPaymentDate), active: active,
            notes: notes.isEmpty ? nil : notes
        )
        isSaving = true
        do {
            if let s = editing { _ = try await SubscriptionsAPI.update(id: s.id, input) }
            else { _ = try await SubscriptionsAPI.create(input) }
            await onSave(); dismiss()
        } catch { self.error = error.localizedDescription }
        isSaving = false
    }
}
