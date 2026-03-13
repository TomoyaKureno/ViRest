import SwiftUI

struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroHeader

                        if let info = viewModel.infoMessage {
                            infoBanner(info)
                        }

                        if let snapshot = viewModel.healthSnapshot {
                            healthCard(snapshot)
                        }

                        if let plan = viewModel.plan {
                            recommendationCard(plan)
                            sessionCard(plan)
                        } else {
                            emptyCard
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("Weekly Plan")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.regenerateNow()
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppPalette.accent)
                    }
                }
            }
            .task {
                viewModel.load()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var heroHeader: some View {
        SurfaceCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cardio recommendation")
                        .font(AppTypography.caption(13))
                        .foregroundStyle(AppPalette.textSecondary)

                    Text("Lower resting HR with a safer weekly rhythm")
                        .font(AppTypography.title(24))
                        .foregroundStyle(AppPalette.textPrimary)
                }

                Spacer(minLength: 8)

                if let plan = viewModel.plan {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(plan.sessions.filter { $0.isCompleted }.count)/\(plan.sessions.count)")
                            .font(AppTypography.hero(24))
                            .foregroundStyle(AppPalette.textPrimary)
                        Text("sessions done")
                            .font(AppTypography.caption(12))
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                }
            }
        }
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.white)
            Text(text)
                .font(AppTypography.caption(13))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [AppPalette.auroraA.opacity(0.8), AppPalette.auroraB.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func healthCard(_ snapshot: HealthSnapshot) -> some View {
        SurfaceCard {
            Text("Health Snapshot")
                .font(AppTypography.title(21))
                .foregroundStyle(AppPalette.textPrimary)

            metricGrid(snapshot)
        }
    }

    private func recommendationCard(_ plan: WeeklyPlan) -> some View {
        SurfaceCard {
            Text("Primary Recommendation")
                .font(AppTypography.title(21))
                .foregroundStyle(AppPalette.textPrimary)

            Text(plan.primaryRecommendation.displayName)
                .font(AppTypography.hero(28))
                .foregroundStyle(AppPalette.textPrimary)

            Text("Target: \(plan.goalFrequency.sessionsPerWeek) activity sessions per week")
                .font(AppTypography.body(15))
                .foregroundStyle(AppPalette.textSecondary)

            Text("\(plan.primaryRecommendation.plannedDurationMinutes) min/session · RPE \(plan.primaryRecommendation.targetRPE.min)-\(plan.primaryRecommendation.targetRPE.max)")
                .font(AppTypography.body(15))
                .foregroundStyle(AppPalette.textSecondary)

            ForEach(plan.primaryRecommendation.reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(AppTypography.caption(13))
                    .foregroundStyle(AppPalette.textSecondary)
            }

            if !plan.alternatives.isEmpty {
                Divider().overlay(.white.opacity(0.2))
                Text("Alternatives")
                    .font(AppTypography.caption(13))
                    .foregroundStyle(AppPalette.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.alternatives) { alternative in
                        HStack {
                            Text(alternative.displayName)
                                .font(AppTypography.body(14))
                                .foregroundStyle(AppPalette.textPrimary)
                            Spacer()
                            Text("\(Int(alternative.score))")
                                .font(AppTypography.caption(12))
                                .foregroundStyle(AppPalette.textSecondary)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func sessionCard(_ plan: WeeklyPlan) -> some View {
        SurfaceCard {
            Text("This Week")
                .font(AppTypography.title(21))
                .foregroundStyle(AppPalette.textPrimary)

            ForEach(plan.sessions) { session in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(session.isCompleted ? AppPalette.accent : AppPalette.textSecondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(session.sessionTitle) · \(session.activity.displayName)")
                            .font(AppTypography.body(15))
                            .foregroundStyle(AppPalette.textPrimary)

                        Text("\(session.plannedDurationMinutes) min · RPE \(session.targetRPE.min)-\(session.targetRPE.max)")
                            .font(AppTypography.caption(12))
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var emptyCard: some View {
        SurfaceCard {
            Text("No plan available yet.")
                .font(AppTypography.body(15))
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    private func metricGrid(_ snapshot: HealthSnapshot) -> some View {
        VStack(spacing: 8) {
            metricRow(leftLabel: "Resting HR", leftValue: formatted(snapshot.restingHeartRate, suffix: "bpm"), rightLabel: "Walking HR", rightValue: formatted(snapshot.walkingHeartRateAverage, suffix: "bpm"))
            metricRow(leftLabel: "VO2 Max", leftValue: formatted(snapshot.vo2Max, suffix: "ml/kg/min"), rightLabel: "HR Recovery", rightValue: formatted(snapshot.heartRateRecovery, suffix: "bpm"))
        }
    }

    private func metricRow(leftLabel: String, leftValue: String, rightLabel: String, rightValue: String) -> some View {
        HStack(spacing: 8) {
            metricCell(label: leftLabel, value: leftValue)
            metricCell(label: rightLabel, value: rightValue)
        }
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTypography.caption(12))
                .foregroundStyle(AppPalette.textSecondary)
            Text(value)
                .font(AppTypography.title(16))
                .foregroundStyle(AppPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f %@", value, suffix)
    }
}

@MainActor
private struct HomePreviewHost: View {
    private let container: AppContainer
    private let viewModel: HomeViewModel

    init() {
        let seededContainer = PreviewSupport.makeSeededContainer()
        self.container = seededContainer
        self.viewModel = HomeViewModel(
            userProfileRepository: seededContainer.userProfileRepository,
            planRepository: seededContainer.planRepository,
            checkInRepository: seededContainer.checkInRepository,
            healthService: seededContainer.healthService,
            recommendationEngine: seededContainer.recommendationEngine,
            notificationService: seededContainer.notificationService
        )
    }

    var body: some View {
        HomeView(viewModel: viewModel)
    }
}

#Preview("Home") {
    HomePreviewHost()
}
