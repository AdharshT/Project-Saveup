import SwiftUI
import LinkKit

struct ConnectBankView: View {
    let onSync: () async -> Void
    @SwiftUI.Environment(\.dismiss) var dismiss

    @State private var linkToken: String?
    @State private var isLoading = true
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    statusView(message: "Preparing secure connection…")
                } else if isSyncing {
                    statusView(message: syncMessage ?? "Importing transactions…")
                } else if let token = linkToken {
                    PlaidLinkView(token: token) { success in
                        Task { await exchange(publicToken: success.publicToken) }
                    } onExit: { exit in
                        if let err = exit.error {
                            errorMessage = err.displayMessage ?? "An error occurred."
                        } else {
                            dismiss()
                        }
                    } onEvent: { _ in
                    } errorView: { error in
                        errorBody(message: error.localizedDescription)
                    }
                } else if let err = errorMessage {
                    errorBody(message: err)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Connect Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await fetchLinkToken() }
    }

    // MARK: - Sub-views

    private func statusView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBody(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48)).foregroundStyle(.orange)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { Task { await fetchLinkToken() } }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.18, green: 0.48, blue: 0.31))
        }
        .padding(32)
    }

    // MARK: - Actions

    private func fetchLinkToken() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await PlaidAPI.linkToken()
            linkToken = response.linkToken
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func exchange(publicToken: String) async {
        isSyncing = true
        syncMessage = "Linking account…"
        do {
            try await PlaidAPI.exchange(publicToken: publicToken)
            syncMessage = "Importing transactions…"
            let result = try await PlaidAPI.sync()
            syncMessage = "Imported \(result.imported) transaction\(result.imported == 1 ? "" : "s")"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await onSync()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSyncing = false
        }
    }
}
