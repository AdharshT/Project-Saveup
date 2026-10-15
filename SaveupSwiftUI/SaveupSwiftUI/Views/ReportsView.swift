import SwiftUI

struct ReportsView: View {
    @AppStorage("claude_api_key") private var apiKey = ""
    @AppStorage("claude_saved_report") private var report = ""
    @AppStorage("claude_report_date") private var reportDateISO = ""

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showKeyEntry = false
    @State private var draftKey = ""

    @State private var transactions: [Transaction] = []
    @State private var accounts: [Account] = []
    @State private var subscriptions: [Subscription] = []
    @State private var incomes: [Income] = []
    @State private var comparison: MonthlyComparison?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                mainContent
            }
        }
        .task { await load() }
        .sheet(isPresented: $showKeyEntry) { keyEntrySheet }
    }

    // MARK: - Main content

    private var mainContent: some View {
        List {
            Section("Claude AI") {
                HStack {
                    Label(
                        apiKey.isEmpty ? "No API key set" : "API key configured",
                        systemImage: apiKey.isEmpty ? "key.slash" : "key.fill"
                    )
                    .foregroundStyle(apiKey.isEmpty ? .secondary : .primary)
                    Spacer()
                    Button(apiKey.isEmpty ? "Add Key" : "Change") {
                        draftKey = apiKey
                        showKeyEntry = true
                    }
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.31))
                }

                if let err = errorMessage {
                    Text(err).font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }

                Button { Task { await generate() } } label: {
                    if isGenerating {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Generating…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Generate AI Report", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.18, green: 0.48, blue: 0.31))
                .disabled(apiKey.isEmpty || isGenerating)
            }

            if !report.isEmpty {
                Section {
                    Text(report)
                        .font(.subheadline)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Clear Report", role: .destructive) {
                        report = ""
                        reportDateISO = ""
                    }
                    .font(.footnote)
                    .buttonStyle(.borderless)
                } header: {
                    HStack {
                        Text("Your Financial Report")
                        Spacer()
                        if !reportDateISO.isEmpty {
                            Text("Saved \(formattedReportDate)")
                                .textCase(nil)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if !isGenerating {
                Section {
                    Text("Tap \"Generate AI Report\" to get a personalized analysis of your spending, subscriptions, and income.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - API key sheet

    private var keyEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-api03-…", text: $draftKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Create a key at console.anthropic.com. It is stored locally on this device only.")
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showKeyEntry = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apiKey = draftKey.trimmingCharacters(in: .whitespaces)
                        showKeyEntry = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var formattedReportDate: String {
        guard let date = ISO8601DateFormatter().date(from: reportDateISO) else { return "" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private func generate() async {
        errorMessage = nil
        isGenerating = true
        do {
            let generated = try await ClaudeReportAPI.generateReport(
                apiKey: apiKey,
                transactions: transactions,
                accounts: accounts,
                subscriptions: subscriptions,
                incomes: incomes,
                comparison: comparison
            )
            report = generated
            reportDateISO = ISO8601DateFormatter().string(from: Date())
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func load() async {
        async let t = try? TransactionsAPI.list()
        async let a = try? AccountsAPI.list()
        async let s = try? SubscriptionsAPI.list()
        async let i = try? IncomesAPI.list()
        async let m = try? SummaryAPI.monthly(months: 6)
        let (txns, accts, subs, inc, monthly) = await (t, a, s, i, m)
        transactions = txns ?? []
        accounts = accts ?? []
        subscriptions = subs ?? []
        incomes = inc ?? []
        comparison = monthly
        isLoading = false
    }
}
