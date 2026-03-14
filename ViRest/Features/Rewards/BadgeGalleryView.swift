import SwiftUI

struct BadgeGalleryView: View {
    @ObservedObject var viewModel: RewardsViewModel
    @State private var selectedBadgeType: BadgeType?
    @State private var detailSheetHeight: CGFloat = 320

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color.richBlack.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(BadgeType.allCases) { badgeType in
                        badgeCircle(for: badgeType)
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("All Badges")
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $selectedBadgeType) { badgeType in
            badgeDetailSheet(for: badgeType)
                .onIntrinsicHeightChange { contentHeight in
                    detailSheetHeight = SheetSizing.fittedHeight(
                        from: contentHeight,
                        minHeight: 260,
                        maxFraction: 0.78,
                        extra: 24
                    )
                }
                .presentationDetents([.height(detailSheetHeight)])
                .presentationDragIndicator(.visible)
        }
    }

    private func badgeCircle(for badgeType: BadgeType) -> some View {
        let earned = viewModel.badgeState.earnedBadges.first { $0.type == badgeType }

        return Button {
            selectedBadgeType = badgeType
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(earned == nil ? Color.white.opacity(0.08) : AppPalette.accent.opacity(0.18))
                        .overlay(
                            Circle().stroke(
                                earned == nil ? Color.white.opacity(0.16) : AppPalette.accent.opacity(0.8),
                                lineWidth: 1.2
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: earned == nil ? "lock.fill" : badgeType.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(earned == nil ? AppPalette.textSecondary : AppPalette.accent)
                }

                Text(badgeType.title)
                    .font(AppTypography.caption(12))
                    .foregroundStyle(AppPalette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func badgeDetailSheet(for badgeType: BadgeType) -> some View {
        let earned = viewModel.badgeState.earnedBadges.first { $0.type == badgeType }
        let criterion = viewModel.badgeState.criterion(for: badgeType)
        let target = max(1, criterion?.targetValue ?? 1)
        let current = criterion.map { viewModel.badgeState.metricValue(for: $0.kind) } ?? 0
        let progress = min(1.0, Double(current) / Double(target))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(earned == nil ? Color.white.opacity(0.08) : AppPalette.accent.opacity(0.18))
                    .overlay(
                        Circle().stroke(
                            earned == nil ? Color.white.opacity(0.16) : AppPalette.accent.opacity(0.8),
                            lineWidth: 1.2
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: earned == nil ? "lock.fill" : badgeType.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(earned == nil ? AppPalette.textSecondary : AppPalette.accent)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(badgeType.title)
                        .font(AppTypography.title(20))
                        .foregroundStyle(AppPalette.textPrimary)
                    Text(earned == nil ? "Locked" : "Unlocked")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(earned == nil ? AppPalette.textSecondary : .green)
                }
            }

            Text(criterion?.summary ?? "Random criteria is being prepared.")
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                    Spacer()
                    Text(criterion?.kind.progressText(current: current, target: target) ?? "0/0")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(earned == nil ? AppPalette.accent : .green)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
            }

            if let earned {
                Text("Unlocked on \(earned.earnedAt.formatted(date: .abbreviated, time: .omitted)).")
                    .font(AppTypography.caption(12))
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
        .padding(16)
        .presentationBackground(Color.richBlack)
    }
}
