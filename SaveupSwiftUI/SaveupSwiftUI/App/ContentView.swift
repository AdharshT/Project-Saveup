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
    case dashboard     = "Dashboard"
    case accounts      = "Accounts"
    case income        = "Income"
    case spending      = "Spending"
    case subscriptions = "Subscriptions"
    case rent          = "Rent & Utilities"
    case affordability = "Can I Afford This?"
    case profile       = "Profile"

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
        case .dashboard:     EmptyView()
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
    @State private var selectedTab: AppTab = .dashboard
    @EnvironmentObject var auth: AuthManager
    @StateObject private var dashboardStore = DashboardStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tabView(for: tab)
                        .navigationTitle(tab.rawValue)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .dashboard {
                Task { await dashboardStore.loadAll() }
            }
        }
    }

    @ViewBuilder
    private func tabView(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(store: dashboardStore)
        default:
            tab.destination
        }
    }
}
