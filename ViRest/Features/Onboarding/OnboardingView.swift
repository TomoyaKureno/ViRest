import SwiftUI

struct OnboardingView: View {
    private enum OnboardingStep: Int, CaseIterable, Identifiable {
        case healthSync
        case physiological
        case healthSafety
        case timeConstraint
        case environment
        case preferences
        case goals

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .healthSync:
                return "Connect Apple Health"
            case .physiological:
                return "Physiological - Cardiovascular"
            case .healthSafety:
                return "Health Safety"
            case .timeConstraint:
                return "Time Constraint"
            case .environment:
                return "Environment"
            case .preferences:
                return "Sport Preferences"
            case .goals:
                return "Weekly Goal"
            }
        }

        var subtitle: String {
            switch self {
            case .healthSync:
                return "Import Health data first so key parameters are prefilled automatically."
            case .physiological:
                return "Set current and target resting HR, then confirm body metrics."
            case .healthSafety:
                return "Safety filters are applied before recommendation ranking."
            case .timeConstraint:
                return "Your available duration and weekly cadence shape session design."
            case .environment:
                return "Location and equipment determine activity feasibility."
            case .preferences:
                return "Set intensity, social mode, and consistency profile."
            case .goals:
                return "Set weekly activity frequency and confirm disclaimer."
            }
        }
    }

    @ObservedObject private var viewModel: OnboardingViewModel
    @State private var currentStep: OnboardingStep = .healthSync

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            AppGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    heroSection
                    progressSection
                    stepContent
                    actionSection
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .task(id: currentStep) {
            if currentStep == .healthSync {
                viewModel.autoImportHealthDataIfNeeded()
            }
        }
    }

    private var heroSection: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [AppPalette.auroraA, AppPalette.auroraB],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentStep.title)
                        .font(AppTypography.hero(30))
                        .foregroundStyle(AppPalette.textPrimary)
                    Text(currentStep.subtitle)
                        .font(AppTypography.body(15))
                        .foregroundStyle(AppPalette.textSecondary)
                }
            }
        }
    }

    private var progressSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                        .font(AppTypography.caption(13))
                        .foregroundStyle(AppPalette.textSecondary)
                    Spacer()
                    Text("\(Int(stepProgress * 100))%")
                        .font(AppTypography.caption(13))
                        .foregroundStyle(AppPalette.textPrimary)
                }

                ProgressView(value: stepProgress)
                    .tint(AppPalette.accent)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .healthSync:
            healthSyncSection
        case .physiological:
            physiologicalSection
        case .healthSafety:
            healthSafetySection
        case .timeConstraint:
            scheduleSection
        case .environment:
            environmentSection
        case .preferences:
            preferenceSection
        case .goals:
            goalSection
            disclaimerSection
        }
    }

    private var healthSyncSection: some View {
        SurfaceCard {
            sectionTitle("Apple Health Sync", icon: "heart.text.square")

            Text("Consent popup appears automatically. If data exists in Apple Health, fields will be prefilled.")
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textSecondary)

            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppPalette.accent)
                    Text("Requesting Health access and preparing data...")
                        .font(AppTypography.body(14))
                        .foregroundStyle(AppPalette.textPrimary)
                }
            }

            switch viewModel.healthImportState {
            case .idle, .requestingConsent:
                EmptyView()
            case .imported:
                statusPill(text: "Health data imported", color: .green)
            case .noData:
                statusPill(text: "No Health data found yet", color: .orange)
            case .denied:
                statusPill(text: "Health permission denied", color: .red)
            }

            if let snapshot = viewModel.importedHealthSnapshot {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Imported Metrics")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                    Text("Current RHR \(formatted(snapshot.restingHeartRate, suffix: "bpm"))")
                        .font(AppTypography.body(14))
                        .foregroundStyle(AppPalette.textPrimary)
                    Text("Weight \(formatted(snapshot.weightKg, suffix: "kg")) · Height \(formatted(snapshot.heightCm, suffix: "cm"))")
                        .font(AppTypography.body(14))
                        .foregroundStyle(AppPalette.textPrimary)
                    Text("Source: \(snapshot.source.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                }
                .padding(10)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var physiologicalSection: some View {
        SurfaceCard {
            sectionTitle("A. Physiological - Cardiovascular", icon: "heart.circle")

            fieldLabel("Current resting heart rate")
            Picker("Current Resting HR", selection: $viewModel.restingHeartRateRange) {
                ForEach(RestingHeartRateRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            fieldLabel("Your target resting heart rate")
            Picker("Target Resting HR", selection: $viewModel.targetRestingHeartRateRange) {
                ForEach(targetHeartRateOptions) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            fieldLabel("Weight and height")
            HStack(spacing: 10) {
                TextField("Weight (kg)", text: $viewModel.weightKgText)
                    .keyboardType(.decimalPad)
                    .appFieldStyle()

                TextField("Height (cm)", text: $viewModel.heightCmText)
                    .keyboardType(.decimalPad)
                    .appFieldStyle()
            }
        }
    }

    private var healthSafetySection: some View {
        SurfaceCard {
            sectionTitle("B. Health Safety", icon: "cross.case")

            Text("Medical conditions and injury limitations are different, but both are used for safety filtering.")
                .font(AppTypography.body(14))
                .foregroundStyle(AppPalette.textSecondary)

            fieldLabel("Do you have any of these conditions?")
            chipFlow(
                HealthCondition.allCases,
                selected: viewModel.healthConditions,
                label: \.displayName,
                onTap: viewModel.toggleHealthCondition
            )

            fieldLabel("Injury or movement limitation")
            singleChoiceChipFlow(InjuryLimitation.allCases, selected: $viewModel.injuryLimitation) { $0.displayName }
        }
    }

    private var scheduleSection: some View {
        SurfaceCard {
            sectionTitle("C. Time Constraint", icon: "clock.badge.checkmark")

            fieldLabel("How much time can you exercise per session?")
            Picker("Duration per session", selection: $viewModel.sessionDuration) {
                ForEach(SessionDurationOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            fieldLabel("How many days per week can you exercise?")
            singleChoiceChipFlow(DaysPerWeekAvailability.allCases, selected: $viewModel.daysPerWeek) { $0.displayName }

            fieldLabel("When do you prefer to exercise?")
            Picker("Preferred time", selection: $viewModel.preferredTime) {
                ForEach(PreferredTime.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private var environmentSection: some View {
        SurfaceCard {
            sectionTitle("D. Environment", icon: "figure.outdoor.cycle")

            fieldLabel("Where do you prefer to do sport?")
            singleChoiceChipFlow(SportEnvironment.allCases, selected: $viewModel.environment) { $0.displayName }

            fieldLabel("What equipment do you have access to?")

            chipFlow(
                equipmentInputOptions,
                selected: viewModel.equipments,
                label: \.displayName,
                onTap: viewModel.toggleEquipment
            )
        }
    }

    private var preferenceSection: some View {
        SurfaceCard {
            sectionTitle("E. Sport Preferences", icon: "sparkles")

            fieldLabel("Preferred intensity")
            singleChoiceChipFlow(IntensityPreference.allCases, selected: $viewModel.intensityPreference) { $0.displayName }

            fieldLabel("Solo or social activity")
            Picker("Social mode", selection: $viewModel.socialPreference) {
                ForEach(socialInputOptions, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            fieldLabel("How consistent are you usually with exercise?")
            Picker("Consistency", selection: $viewModel.consistency) {
                ForEach(ConsistencyLevel.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private var goalSection: some View {
        SurfaceCard {
            sectionTitle("Weekly Goal", icon: "target")
            WeeklyActivityGoalSelector(goal: $viewModel.weeklyGoal)
        }
    }

    private var disclaimerSection: some View {
        SurfaceCard {
            Toggle(isOn: $viewModel.acceptedDisclaimer) {
                Text("I understand this app provides wellness recommendations, not medical diagnosis.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textPrimary)
            }
            .tint(AppPalette.accentSecondary)
        }
    }

    private var actionSection: some View {
        SurfaceCard {
            VStack(spacing: 12) {
                if let error = currentErrorMessage {
                    Text(error)
                        .font(AppTypography.caption(12))
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    if previousStep != nil {
                        Button("Back") {
                            moveToPreviousStep()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    Button {
                        handlePrimaryAction()
                    } label: {
                        HStack {
                            if viewModel.isLoading && isLastStep {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isLastStep ? "Generate Weekly Plan" : "Next")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isPrimaryDisabled)
                }
            }
        }
    }

    private var stepProgress: Double {
        Double(currentStep.rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    private var nextStep: OnboardingStep? {
        OnboardingStep(rawValue: currentStep.rawValue + 1)
    }

    private var previousStep: OnboardingStep? {
        OnboardingStep(rawValue: currentStep.rawValue - 1)
    }

    private var isLastStep: Bool {
        nextStep == nil
    }

    private var isPrimaryDisabled: Bool {
        viewModel.isLoading || !canProceedCurrentStep
    }

    private var canProceedCurrentStep: Bool {
        stepValidationMessage == nil
    }

    private var currentErrorMessage: String? {
        if let explicit = viewModel.errorMessage {
            return explicit
        }
        return stepValidationMessage
    }

    private var stepValidationMessage: String? {
        switch currentStep {
        case .healthSync:
            return nil
        case .physiological:
            if viewModel.restingHeartRateRange == .unknown {
                return "Current resting heart rate is required."
            }
            if viewModel.targetRestingHeartRateRange == .unknown || viewModel.targetRestingHeartRateRange == .above90 {
                return "Target resting heart rate is required."
            }
            if Double(viewModel.weightKgText) == nil || (Double(viewModel.weightKgText) ?? 0) <= 0 {
                return "Weight is required."
            }
            if Double(viewModel.heightCmText) == nil || (Double(viewModel.heightCmText) ?? 0) <= 0 {
                return "Height is required."
            }
            return nil
        case .healthSafety:
            if viewModel.healthConditions.isEmpty {
                return "Health condition is required."
            }
            return nil
        case .timeConstraint:
            return nil
        case .environment:
            if viewModel.equipments.isEmpty {
                return "At least one equipment option is required."
            }
            return nil
        case .preferences:
            return nil
        case .goals:
            if !viewModel.acceptedDisclaimer {
                return "You must accept the medical disclaimer."
            }
            return nil
        }
    }

    private var equipmentInputOptions: [Equipment] {
        [
            .none,
            .yogaMat,
            .resistanceBands,
            .dumbbells,
            .kettlebell,
            .ankleWeights,
            .bicycle,
            .treadmill,
            .tennisRacket,
            .badmintonRacket,
            .jumpRope,
            .rowingMachine,
            .ellipticalMachine,
            .swimmingPoolAccess,
            .sportsCourtAccess,
            .stairsOrHillAccess,
            .gymMembership
        ]
    }

    private var socialInputOptions: [SocialPreference] {
        [.solo, .withFriends, .either]
    }

    private var targetHeartRateOptions: [RestingHeartRateRange] {
        RestingHeartRateRange.allCases.filter { $0 != .unknown && $0 != .above90 }
    }

    private func handlePrimaryAction() {
        viewModel.errorMessage = nil

        if isLastStep {
            viewModel.submit()
            return
        }

        moveToNextStep()
    }

    private func moveToNextStep() {
        guard let nextStep else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = nextStep
        }
    }

    private func moveToPreviousStep() {
        guard let previousStep else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = previousStep
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

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption(13))
            .foregroundStyle(AppPalette.textSecondary)
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f %@", value, suffix)
    }

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(AppTypography.caption(12))
            .foregroundStyle(color.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func chipFlow<Option: Hashable>(
        _ options: [Option],
        selected: Set<Option>,
        label: @escaping (Option) -> String,
        onTap: @escaping (Option) -> Void
    ) -> some View {
        let columns = [GridItem(.adaptive(minimum: 128), spacing: 9)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
            ForEach(Array(options.indices), id: \.self) { index in
                let option = options[index]
                SelectableChip(title: label(option), isSelected: selected.contains(option)) {
                    onTap(option)
                }
            }
        }
    }

    private func singleChoiceChipFlow<Option: Hashable>(
        _ options: [Option],
        selected: Binding<Option>,
        label: @escaping (Option) -> String
    ) -> some View {
        let columns = [GridItem(.adaptive(minimum: 128), spacing: 9)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
            ForEach(Array(options.indices), id: \.self) { index in
                let option = options[index]
                SelectableChip(
                    title: label(option),
                    isSelected: selected.wrappedValue == option
                ) {
                    selected.wrappedValue = option
                }
            }
        }
    }
}
