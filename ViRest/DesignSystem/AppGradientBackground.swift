import SwiftUI

struct AppGradientBackground: View {
    var body: some View {
        ZStack {
            Color.richBlack

            Circle()
                .fill(AppPalette.auroraA.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 46)
                .offset(x: -120, y: -220)

            Circle()
                .fill(AppPalette.auroraB.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 44)
                .offset(x: 120, y: 220)
        }
        .ignoresSafeArea()
    }
}
