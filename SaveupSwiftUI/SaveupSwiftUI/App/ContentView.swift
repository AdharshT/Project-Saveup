import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            if !auth.ready {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if auth.user == nil {
                AuthNavigationView()
            } else {
                MainNavigationView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.ready)
        .animation(.easeInOut(duration: 0.2), value: auth.user?.id)
    }
}

struct AuthNavigationView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard    = "Dashboard"
    case accounts     = "Accounts"
    case subscriptions = "Subscriptions"
    case rent         = "Rent & Utilities"
    case income       = "Income"
    case spending     = "Spending"
    case affordability = "Can I Afford This?"
    case profile      = "Profile"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard:     "chart.bar.fill"
        case .accounts:      "banknote.fill"
        case .subscriptions: "repeat.circle.fill"
        case .rent:          "house.fill"
        case .income:        "dollarsign.circle.fill"
        case .spending:      "cart.fill"
        case .affordability: "questionmark.circle.fill"
        case .profile:       "person.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .dashboard:     DashboardView()
        case .accounts:      AccountsView()
        case .subscriptions: SubscriptionsView()
        case .rent:          RentView()
        case .income:        IncomeView()
        case .spending:      SpendingView()
        case .affordability: AffordabilityView()
        case .profile:       ProfileView()
        }
    }
}

struct MainNavigationView: View {
    @State private var selectedTab: AppTab? = .dashboard
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationTitle("Saveup")
            .safeAreaInset(edge: .bottom) {
                if let user = auth.user {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 32, height: 32)
                            Text(getInitials(user.name))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.name).font(.subheadline.weight(.medium))
                            Text(user.email).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
        } detail: {
            if let tab = selectedTab {
                NavigationStack {
                    tab.destination
                        .navigationTitle(tab.rawValue)
                }
            } else {
                ContentUnavailableView("Select a Section", systemImage: "sidebar.left")
            }
        }
    }
}
