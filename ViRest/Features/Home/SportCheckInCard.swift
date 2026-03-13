//
//  SportCheckInCard.swift
//  ViRest
//
//  Created by Joshua Valentine Manik on 13/03/26.
//

import SwiftUI

struct SportCheckInCard: View {
    let sport: FirestoreSportEntry
    let onCheckIn: () -> Void

    private var progress: Double {
        guard sport.weeklyTargetCount > 0 else { return 0 }
        return min(1.0, Double(sport.completedThisWeek) / Double(sport.weeklyTargetCount))
    }

    private var isTargetMet: Bool {
        sport.completedThisWeek >= sport.weeklyTargetCount
    }

    var body: some View {
        SurfaceCard {
            VStack(spacing: 10) {
                // Top row: name + counter + button
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sport.displayName)
                            .font(AppTypography.title(20))
                            .foregroundStyle(AppPalette.textPrimary)
                        Text("\(sport.durationMinutes) min/session")
                            .font(AppTypography.caption(13))
                            .foregroundStyle(AppPalette.textSecondary)
                        Text("Target: \(sport.weeklyTargetCount)x this week")
                            .font(AppTypography.caption(13))
                            .foregroundStyle(AppPalette.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        // Counter: X/N
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(sport.completedThisWeek)")
                                .font(AppTypography.hero(24))
                                .foregroundStyle(isTargetMet ? .green : AppPalette.accent)
                            Text("/\(sport.weeklyTargetCount)")
                                .font(AppTypography.body(16))
                                .foregroundStyle(AppPalette.textSecondary)
                        }

                        // Plus / checkmark button
                        Button(action: onCheckIn) {
                            ZStack {
                                Circle()
                                    .fill(isTargetMet ? Color.green : AppPalette.accent)
                                    .frame(width: 44, height: 44)
                                Image(systemName: isTargetMet ? "checkmark" : "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(isTargetMet)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        Capsule()
                            .fill(isTargetMet ? Color.green : AppPalette.accent)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)

                // Weekly target met label
                if isTargetMet {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text("Weekly target met!")
                            .font(AppTypography.caption(13))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
