import SwiftUI

struct AppGradientBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppPalette.auroraA.opacity(0.35))
                .frame(width: 340, height: 340)
                .blur(radius: 36)
                .offset(x: animate ? -120 : -50, y: animate ? -210 : -120)

            Circle()
                .fill(AppPalette.auroraB.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 48)
                .offset(x: animate ? 130 : 70, y: animate ? 180 : 110)

            Circle()
                .fill(AppPalette.auroraC.opacity(0.25))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: animate ? 100 : 150, y: animate ? -180 : -120)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
