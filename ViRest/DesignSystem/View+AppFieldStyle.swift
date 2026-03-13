import SwiftUI

private struct AppFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.body(16))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
    }
}

extension View {
    func appFieldStyle() -> some View {
        modifier(AppFieldModifier())
    }
}
