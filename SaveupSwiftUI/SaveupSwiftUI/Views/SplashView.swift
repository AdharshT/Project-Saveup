import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.78, blue: 0.40),
                    Color(red: 0.08, green: 0.38, blue: 0.18)
                ],
                center: .center,
                startRadius: 60,
                endRadius: 520
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 380)
                .offset(x: -150, y: -310)

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 430)
                .offset(x: 185, y: 370)

            VStack(spacing: 20) {
                Image("LaunchImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210, height: 210)

                Text("Track  ·  Plan  ·  Save")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(2.5)
            }
        }
    }
}
