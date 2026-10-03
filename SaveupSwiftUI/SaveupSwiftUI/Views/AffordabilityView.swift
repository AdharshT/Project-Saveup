import SwiftUI

struct AffordabilityView: View {
    @State private var basket: [(id: UUID, name: String, price: Double)] = []
    @State private var itemName = ""
    @State private var itemPrice = ""
    @State private var editingBasketId: UUID? = nil
    @State private var result: AffordabilityResponse?
    @State private var isChecking = false
    @State private var addError: String?

    @State private var history: [AffordabilityResponse] = []
    @State private var historyLoading = true
    @State private var expandedHistoryId: Int? = nil

    private var basketTotal: Double { basket.reduce(0) { $0 + $1.price } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Add item form
                GroupBox(editingBasketId != nil ? "Edit Basket Item" : "Add Item to Basket") {
                    VStack(spacing: 12) {
                        if let err = addError {
                            Text(err).font(.footnote).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(spacing: 12) {
                            TextField("Item name", text: $itemName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Price", text: $itemPrice)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                                .frame(width: 90)
                        }
                        HStack {
                            Button(editingBasketId != nil ? "Save Changes" : "Add to Basket") {
                                handleAddItem()
                            }
                            .buttonStyle(.borderedProminent)
                            if editingBasketId != nil {
                                Button("Cancel") { cancelEditItem() }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                // Basket
                GroupBox {
                    VStack(spacing: 8) {
                        if basket.isEmpty {
                            Text("Your basket is empty.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        ForEach(basket, id: \.id) { item in
                            HStack {
                                Text(item.name).font(.subheadline)
                                Spacer()
                                Text(formatCurrency(item.price)).font(.subheadline)
                                Button("Edit") { startEditItem(item) }
                                    .font(.footnote).foregroundStyle(.accentColor)
                                Button("Remove") { removeItem(item.id) }
                                    .font(.footnote).foregroundStyle(.red)
                            }
                        }
                        Divider()
                        Button(isChecking ? "Checking..." : "Check Affordability") {
                            Task { await checkAffordability() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isChecking || basket.isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                } label: {
                    HStack {
                        Text("Basket").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("Total: \(formatCurrency(basketTotal))").font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Result
                if let res = result {
                    AffordabilityResultCard(result: res)
                }

                // History
                GroupBox("History") {
                    if historyLoading {
                        ProgressView()
                    } else if history.isEmpty {
                        Text("No past checks yet.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(history) { entry in
                            HistoryRow(
                                entry: entry,
                                isExpanded: expandedHistoryId == entry.id,
                                onToggle: {
                                    expandedHistoryId = expandedHistoryId == entry.id ? nil : entry.id
                                },
                                onDelete: { Task { await deleteHistory(entry.id) } }
                            )
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
        .task {
            history = (try? await AffordabilityAPI.history()) ?? []
            historyLoading = false
        }
    }

    private func handleAddItem() {
        addError = nil
        let name = itemName.trimmingCharacters(in: .whitespaces)
        guard let price = Double(itemPrice), !name.isEmpty else {
            addError = "Item name and price are required."
            return
        }
        if let editId = editingBasketId {
            basket = basket.map { $0.id == editId ? (editId, name, price) : $0 }
            editingBasketId = nil
        } else {
            basket.append((UUID(), name, price))
        }
        itemName = ""; itemPrice = ""
        result = nil
    }

    private func startEditItem(_ item: (id: UUID, name: String, price: Double)) {
        editingBasketId = item.id
        itemName = item.name
        itemPrice = String(item.price)
    }

    private func cancelEditItem() {
        editingBasketId = nil; itemName = ""; itemPrice = ""
    }

    private func removeItem(_ id: UUID) {
        if editingBasketId == id { cancelEditItem() }
        basket.removeAll { $0.id == id }
        result = nil
    }

    private func checkAffordability() async {
        addError = nil
        isChecking = true
        do {
            let items = basket.map { BasketItemInput(name: $0.name, price: $0.price) }
            let res = try await AffordabilityAPI.check(items: items)
            result = res
            history.insert(res, at: 0)
        } catch {
            addError = error.localizedDescription
        }
        isChecking = false
    }

    private func deleteHistory(_ id: Int) async {
        try? await AffordabilityAPI.removeHistory(id: id)
        history.removeAll { $0.id == id }
        if result?.id == id { result = nil }
    }
}

private struct AffordabilityResultCard: View {
    let result: AffordabilityResponse

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.message).font(.footnote)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCell(label: "Monthly Income", value: formatCurrency(result.monthlyIncome))
                    StatCell(label: "Monthly Subscriptions", value: formatCurrency(result.monthlySubscriptionCost))
                    StatCell(label: "Spent This Month", value: formatCurrency(result.spendingThisMonth))
                    StatCell(label: "Discretionary Balance", value: formatCurrency(result.discretionaryBalance))
                    StatCell(label: "Balance After Purchase", value: formatCurrency(result.balanceAfterPurchase))
                }
            }
        } label: {
            HStack {
                Image(systemName: result.canAfford ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result.canAfford ? .green : .orange)
                Text(result.canAfford ? "You can afford it" : "This may be a stretch")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.canAfford ? .green : .orange)
            }
        }
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryRow: View {
    let entry: AffordabilityResponse
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium; df.timeStyle = .none
        if let d = ISO8601DateFormatter().date(from: entry.createdAt) { return df.string(from: d) }
        return String(entry.createdAt.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onToggle) {
                    Text("\(formattedDate) — \(entry.items.map { $0.name }.joined(separator: ", "))")
                        .font(.footnote).multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(entry.canAfford ? "Affordable" : "Over budget")
                    .font(.caption).foregroundStyle(entry.canAfford ? .green : .red)
                Text(formatCurrency(entry.totalPrice)).font(.caption)
                Button("Delete", action: onDelete).font(.footnote).foregroundStyle(.red)
            }
            if isExpanded {
                ForEach(entry.items) { item in
                    HStack {
                        Text(item.name).font(.caption)
                        Spacer()
                        Text(formatCurrency(item.price)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }
        }
    }
}
