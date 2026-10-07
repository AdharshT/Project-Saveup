import SwiftUI

@main
struct SaveupApp: App {
    @StateObject private var auth = AuthManager()
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if splashDone && auth.ready {
                    ContentView()
                        .environmentObject(auth)
                        .transition(.opacity)
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.4), value: splashDone && auth.ready)
            .onAppear {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    splashDone = true
                }
            }
        }
    }
}
