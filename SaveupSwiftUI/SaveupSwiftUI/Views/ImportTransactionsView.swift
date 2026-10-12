import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ImportTransactionsView: View {
    let accounts: [Account]
    let onImport: () async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedAccountId: Int = -1
    @State private var parsedTransactions: [ParsedTransaction] = []
    @State private var selectedRows: Set<UUID> = []
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if parsedTransactions.isEmpty {
                    instructionsView
                } else {
                    previewList
                }
            }
            .navigationTitle("Import PDF Statement")
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
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url): loadPDF(from: url)
                case .failure: errorMessage = "Could not open the file."
                }
            }
            .onAppear { selectedAccountId = accounts.first?.id ?? -1 }
        }
    }

    // MARK: - Instructions screen

    private var instructionsView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.22, green: 0.78, blue: 0.40))

                VStack(spacing: 8) {
                    Text("Import Bank Statement PDF")
                        .font(.title2.weight(.semibold))
                    Text("Download your bank statement as a PDF, then tap Choose File. Transactions will be extracted automatically.")
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
                    Label("Best results with text-based PDFs", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Scanned image PDFs may not parse correctly.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let err = errorMessage {
                    Text(err).foregroundStyle(.red).font(.footnote).multilineTextAlignment(.center)
                }

                Button { showFilePicker = true } label: {
                    Label("Choose PDF File", systemImage: "folder")
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

            Section {
                ForEach(parsedTransactions) { txn in
                    HStack(spacing: 12) {
                        Image(systemName: selectedRows.contains(txn.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedRows.contains(txn.id) ? Color(red: 0.22, green: 0.78, blue: 0.40) : .secondary)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(txn.description).font(.subheadline).lineLimit(1)
                            HStack(spacing: 4) {
                                Text(txn.date.formatted(date: .abbreviated, time: .omitted))
                                if let cat = txn.category { Text("· \(cat)") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatCurrency(txn.amount)).font(.subheadline.weight(.medium))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(txn.id) }
                }
            } header: {
                HStack {
                    Text("\(parsedTransactions.count) transactions found")
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

    // MARK: - Actions

    private func toggle(_ id: UUID) {
        if selectedRows.contains(id) { selectedRows.remove(id) } else { selectedRows.insert(id) }
    }

    private func loadPDF(from url: URL) {
        errorMessage = nil
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Permission denied to read this file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let rows = PDFImporter.parse(url: url)
        if rows.isEmpty {
            errorMessage = "No transactions found. Make sure this is a text-based bank statement PDF (not a scanned image)."
        } else {
            parsedTransactions = rows
            selectedRows = Set(rows.map(\.id))
        }
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
    ("Chase", "Accounts → See activity → Download → PDF"),
    ("Bank of America", "Account Details → View Statements → Download PDF"),
    ("Wells Fargo", "Statements & Documents → View Statement"),
    ("Citi", "Account → Statements → Download PDF"),
    ("Capital One", "Account → View Statements → Download"),
]
