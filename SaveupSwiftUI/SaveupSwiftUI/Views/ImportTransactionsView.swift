import SwiftUI
import UniformTypeIdentifiers

struct ImportTransactionsView: View {
    let accounts: [Account]
    let onImport: () async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedAccountId: Int = -1
    @State private var parsedTransactions: [ParsedTransaction] = []
    @State private var selectedRows: Set<UUID> = []
    @State private var duplicateIDs: Set<UUID> = []
    @State private var existingTransactions: [Transaction] = []
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var newCount: Int { parsedTransactions.filter { !duplicateIDs.contains($0.id) }.count }
    private var dupCount: Int  { duplicateIDs.count }

    var body: some View {
        NavigationStack {
            Group {
                if parsedTransactions.isEmpty {
                    instructionsView
                } else {
                    previewList
                }
            }
            .navigationTitle("Import CSV Statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if !parsedTransactions.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isImporting ? "Importing…" : "Import \(selectedRows.count)") {
                            Task { await importSelected() }
                        }
                        .disabled(selectedRows.isEmpty || isImporting)
                    }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url): Task { await loadCSV(from: url) }
                case .failure: errorMessage = "Could not open the file."
                }
            }
            .task {
                selectedAccountId = accounts.first?.id ?? -1
                existingTransactions = (try? await TransactionsAPI.list()) ?? []
            }
        }
    }

    // MARK: - Instructions screen

    private var instructionsView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "tablecells.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.22, green: 0.78, blue: 0.40))

                VStack(spacing: 8) {
                    Text("Import Bank Statement CSV")
                        .font(.title2.weight(.semibold))
                    Text("Download your bank statement as a CSV file, then tap Choose File. Transactions will be imported automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(bankInstructions, id: \.bank) { info in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(info.bank).font(.footnote.weight(.semibold))
                            Text(info.path).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        if info.bank != bankInstructions.last?.bank {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                VStack(spacing: 6) {
                    Label("CSV must have Date, Description, and Amount columns", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Separate Debit/Credit columns are also supported.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let err = errorMessage {
                    Text(err).foregroundStyle(.red).font(.footnote).multilineTextAlignment(.center)
                }

                Button { showFilePicker = true } label: {
                    Label("Choose CSV File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(red: 0.22, green: 0.78, blue: 0.40))
            }
            .padding(24)
        }
    }

    // MARK: - Preview list

    private var previewList: some View {
        List {
            Section("Import to Account") {
                Picker("Account", selection: $selectedAccountId) {
                    ForEach(accounts) { a in Text(a.nickname).tag(a.id) }
                }
                .pickerStyle(.menu)
            }

            // Duplicate summary banner
            if dupCount > 0 {
                Section {
                    Label(
                        "\(dupCount) duplicate\(dupCount == 1 ? "" : "s") skipped — already in your logs",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(parsedTransactions) { txn in
                    let isDup = duplicateIDs.contains(txn.id)
                    HStack(spacing: 12) {
                        Image(systemName: selectedRows.contains(txn.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                selectedRows.contains(txn.id)
                                    ? Color(red: 0.22, green: 0.78, blue: 0.40)
                                    : .secondary
                            )
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(txn.description)
                                .font(.subheadline)
                                .lineLimit(1)
                                .foregroundStyle(isDup ? .secondary : .primary)
                            HStack(spacing: 4) {
                                Text(txn.date.formatted(date: .abbreviated, time: .omitted))
                                if let cat = txn.category { Text("· \(cat)") }
                                if isDup {
                                    Text("· Already logged")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }

                        Spacer()
                        Text(formatCurrency(txn.amount))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isDup ? .secondary : .primary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(txn.id) }
                }
            } header: {
                HStack {
                    if dupCount > 0 {
                        Text("\(newCount) new · \(dupCount) duplicate\(dupCount == 1 ? "" : "s")")
                    } else {
                        Text("\(parsedTransactions.count) transactions found")
                    }
                    Spacer()
                    Button(selectedRows.count == parsedTransactions.count ? "Deselect All" : "Select All") {
                        if selectedRows.count == parsedTransactions.count {
                            selectedRows = []
                        } else {
                            selectedRows = Set(parsedTransactions.map(\.id))
                        }
                    }
                    .font(.caption).buttonStyle(.borderless)
                }
            }

            if let err = errorMessage {
                Section { Text(err).foregroundStyle(.red).font(.footnote) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Duplicate detection

    private func isDuplicate(_ parsed: ParsedTransaction) -> Bool {
        let dateStr = formatISODate(parsed.date)
        let desc = parsed.description.lowercased().trimmingCharacters(in: .whitespaces)
        return existingTransactions.contains { existing in
            existing.date == dateStr &&
            abs(existing.amount - parsed.amount) < 0.01 &&
            existing.description.lowercased().trimmingCharacters(in: .whitespaces) == desc
        }
    }

    // MARK: - Actions

    private func toggle(_ id: UUID) {
        if selectedRows.contains(id) { selectedRows.remove(id) } else { selectedRows.insert(id) }
    }

    private func loadCSV(from url: URL) async {
        errorMessage = nil
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Permission denied to read this file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let rows = CSVImporter.parse(url: url)
        guard !rows.isEmpty else {
            errorMessage = "No transactions found. Make sure the CSV has Date, Description, and Amount columns."
            return
        }

        // Re-fetch so we have the freshest list before dedup check
        let fresh = (try? await TransactionsAPI.list()) ?? existingTransactions
        existingTransactions = fresh

        let dups = Set(rows.filter { isDuplicate($0) }.map(\.id))
        parsedTransactions = rows
        duplicateIDs = dups
        // Pre-select only non-duplicates
        selectedRows = Set(rows.filter { !dups.contains($0.id) }.map(\.id))
    }

    private func importSelected() async {
        isImporting = true
        errorMessage = nil
        let toImport = parsedTransactions.filter { selectedRows.contains($0.id) }
        do {
            for txn in toImport {
                let input = TransactionInput(
                    accountId: selectedAccountId,
                    description: txn.description,
                    amount: txn.amount,
                    category: txn.category,
                    date: formatISODate(txn.date)
                )
                _ = try await TransactionsAPI.create(input)
            }
            await onImport()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
    }
}

private let bankInstructions: [(bank: String, path: String)] = [
    ("Chase", "Accounts → See activity → Download → CSV"),
    ("Bank of America", "Account Details → Download Transactions → CSV"),
    ("Wells Fargo", "Statements & Documents → Download → Comma Delimited"),
    ("Citi", "Account → Download Transactions → CSV"),
    ("Capital One", "Account → Download → CSV"),
]
