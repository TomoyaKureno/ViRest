import SwiftUI

struct CheckInView: View {
    @ObservedObject private var viewModel: CheckInViewModel

    init(viewModel: CheckInViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroSection

                        if viewModel.pendingSessions.isEmpty {
                            SurfaceCard {
                                Text("No pending sessions. Great momentum this week.")
                                    .font(AppTypography.body(15))
                                    .foregroundStyle(AppPalette.textSecondary)
                            }
                        } else {
                            sessionPickerCard
                            feedbackCard
                            submitCard
                        }

                        if let assessment = viewModel.assessment {
                            assessmentCard(assessment)
                        }

                        if let appreciation = viewModel.appreciationText {
                            SurfaceCard {
                                sectionTitle("Appreciation", icon: "hands.clap")
                                Text(appreciation)
                                    .font(AppTypography.body(15))
                                    .foregroundStyle(AppPalette.textPrimary)
                            }
                        }

                        if !viewModel.newBadges.isEmpty {
                            SurfaceCard {
                                sectionTitle("New Badges", icon: "rosette")
                                ForEach(viewModel.newBadges) { badge in
                                    Text("• \(badge.type.title)")
                                        .font(AppTypography.body(14))
                                        .foregroundStyle(AppPalette.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("Check-In")
            .toolbarTitleDisplayMode(.inline)
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

    private var heroSection: some View {
        SurfaceCard {
            Text("Post-activity suitability")
                .font(AppTypography.title(24))
                .foregroundStyle(AppPalette.textPrimary)
            Text("Your feedback here drives safe weekly adjustments and progression.")
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textSecondary)
        }
    }

    private var sessionPickerCard: some View {
        SurfaceCard {
            sectionTitle("Select Session", icon: "calendar.badge.clock")

            questionLabel("Which planned activity did you complete?")
            Picker("Session", selection: $viewModel.selectedSessionId) {
                ForEach(viewModel.pendingSessions) { session in
                    Text("\(session.sessionTitle) · \(session.activity.displayName)")
                        .tag(Optional(session.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private var feedbackCard: some View {
        SurfaceCard {
            sectionTitle("Suitability Confirmation", icon: "checkmark.shield")

            questionLabel("How physically difficult was this activity?")
            Picker("Difficulty", selection: $viewModel.difficulty) {
                ForEach(ActivityDifficulty.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            questionLabel("How tired do you feel after finishing?")
            Picker("Fatigue", selection: $viewModel.fatigue) {
                ForEach(FatigueLevel.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            questionLabel("Did you feel any pain during the activity?")
            Picker("Pain", selection: $viewModel.painLevel) {
                ForEach(PainLevel.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            if viewModel.painLevel != .noPain {
                questionLabel("Where did you feel discomfort?")

                let columns = [GridItem(.adaptive(minimum: 116), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(DiscomfortArea.allCases) { area in
                        SelectableChip(
                            title: area.displayName,
                            isSelected: viewModel.discomfortAreas.contains(area)
                        ) {
                            if viewModel.discomfortAreas.contains(area) {
                                viewModel.discomfortAreas.remove(area)
                            } else {
                                viewModel.discomfortAreas.insert(area)
                            }
                        }
                    }
                }
            } else {
                Text("No discomfort details needed when you choose \"No pain\".")
                    .font(AppTypography.caption(12))
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
    }

    private var submitCard: some View {
        SurfaceCard {
            Button {
                viewModel.submitCheckIn()
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("I Completed This Activity")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.isLoading)
        }
    }

    private func assessmentCard(_ assessment: SuitabilityAssessment) -> some View {
        SurfaceCard {
            sectionTitle("Suitability Result", icon: "gauge.with.dots.needle.50percent")

            Text("Zone: \(assessment.zone.rawValue.capitalized) · Score: \(Int(assessment.score))")
                .font(AppTypography.title(18))
                .foregroundStyle(color(for: assessment.zone))

            Text(assessment.recommendationText)
                .font(AppTypography.body(15))
                .foregroundStyle(AppPalette.textPrimary)

            ForEach(assessment.reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(AppTypography.caption(13))
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppPalette.accent)
            Text(title)
                .font(AppTypography.title(20))
                .foregroundStyle(AppPalette.textPrimary)
        }
    }

    private func questionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption(13))
            .foregroundStyle(AppPalette.textSecondary)
    }

    private func color(for zone: SuitabilityZone) -> Color {
        switch zone {
        case .green: return AppPalette.accent
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

@MainActor
private struct CheckInPreviewHost: View {
    private let container: AppContainer
    private let viewModel: CheckInViewModel

    init() {
        let seededContainer = PreviewSupport.makeSeededContainer()
        self.container = seededContainer
        self.viewModel = CheckInViewModel(
            userProfileRepository: seededContainer.userProfileRepository,
            planRepository: seededContainer.planRepository,
            checkInRepository: seededContainer.checkInRepository,
            badgeRepository: seededContainer.badgeStateRepository,
            healthService: seededContainer.healthService,
            planAdjustmentService: seededContainer.planAdjustmentService,
            gamificationService: seededContainer.gamificationService,
            notificationService: seededContainer.notificationService
        )
    }

    var body: some View {
        CheckInView(viewModel: viewModel)
    }
}

#Preview("Check-In") {
    CheckInPreviewHost()
}
