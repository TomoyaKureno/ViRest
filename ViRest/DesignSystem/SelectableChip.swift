import SwiftUI

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(AppTypography.caption(13))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AppPalette.accent.opacity(0.88) : Color.white.opacity(0.14))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.36) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.74), value: isSelected)
    }
}
