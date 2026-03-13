import SwiftUI

struct OnboardingView: View {
    private enum OnboardingStep: Int, CaseIterable, Identifiable {
        case currentRHR
        case weight
        case height
        case environment
        case preferredTime
        case duration
        case frequency
        case equipment
        case contraindications
        case targetRHR

        var id: Int {
            rawValue
        }

        var title: String {
            switch self {
            case .currentRHR:
                return "1. What is your current resting heart rate (RHR)?"
            case .weight:
                return "2. What is your current weight?"
            case .height:
                return "3. What is your current height?"
            case .environment:
                return "4. Where would you prefer to exercise?"
            case .preferredTime:
                return "5. When do you usually prefer to exercise?"
            case .duration:
                return "6. How much time can you realistically spend exercising in one session?"
            case .frequency:
                return "7. How many days per week can you realistically exercise?"
            case .equipment:
                return "8. What exercise access or equipment do you currently have?"
            case .contraindications:
                return "9. Do you have any of these conditions that should rule out certain exercises?"
            case .targetRHR:
                return "10. What resting heart rate would you like to achieve?"
            }
        }

        var sectionTitle: String {
            switch self {
            case .currentRHR, .weight, .height:
                return "Current Health Baseline"
            case .environment, .preferredTime:
                return "Exercise Preference"
            case .duration, .frequency, .equipment:
                return "Exercise Availability & Commitment"
            case .contraindications:
                return "Safety Screening"
            case .targetRHR:
                return "Goal Setting"
            }
        }

        var isLast: Bool {
            self == .targetRHR
        }
    }

    private struct StepOption: Identifiable {
        let id: String
        let title: String
        let isSelected: Bool
        let action: () -> Void
    }

    private enum NumericInputKind {
        case weight
        case height
    }

    private struct StaticPressButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }

    @ObservedObject private var viewModel: OnboardingViewModel
    @State private var currentStep: OnboardingStep = .currentRHR
    @State private var inlineInputError: String?
    @State private var lastValidWeightInput: String = ""
    @State private var lastValidHeightInput: String = ""
    @State private var hasPresentedHealthKitPrompt = false
    @State private var showHealthKitPrompt = false
    private let onExitFromFirstQuestion: () -> Void

    init(
        viewModel: OnboardingViewModel,
        onExitFromFirstQuestion: @escaping () -> Void = { }
    ) {
        self.viewModel = viewModel
        self.onExitFromFirstQuestion = onExitFromFirstQuestion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    Text("Virest")
                        .font(.headline.bold())
                        .foregroundStyle(Color.slateGray)
                    HStack {
                        Button(action: handleBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 24).bold())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(currentStep.sectionTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.vibrantGreen)

                Text(currentStep.title)
                    .font(.title2)
                    .foregroundStyle(Color.white)

                if let errorMessage = displayedErrorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                        .lineLimit(2)
                }
            }.padding(.horizontal)

            ScrollView {
                stepContent
                    .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            HStack {
                Button(action: handleNext) {
                    let buttonTitle = viewModel.isLoading ? "Loading..." : "Next"
                    Text(buttonTitle)
                        .font(.headline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                }
                .disabled(viewModel.isLoading)
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.richBlack)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: currentStep) { _, _ in
            inlineInputError = nil
            maybePresentHealthKitPromptIfNeeded()
        }
        .onChange(of: viewModel.weightKgText) { _, newValue in
            applyRegexGuard(for: .weight, newValue: newValue)
        }
        .onChange(of: viewModel.heightCmText) { _, newValue in
            applyRegexGuard(for: .height, newValue: newValue)
        }
        .onAppear {
            lastValidWeightInput = normalizeInput(viewModel.weightKgText, kind: .weight)
            lastValidHeightInput = normalizeInput(viewModel.heightCmText, kind: .height)
            maybePresentHealthKitPromptIfNeeded()
        }
        .alert("Apple Health Access", isPresented: $showHealthKitPrompt) {
            Button("Nanti", role: .cancel) { }
            Button("Izinkan") {
                viewModel.importHealthData()
            }
        } message: {
            Text("Izinkan akses HealthKit agar RHR, weight, dan height bisa diisi otomatis.")
        }
    }

    private var displayedErrorMessage: String? {
        inlineInputError ?? (currentStep.isLast ? viewModel.errorMessage : nil)
    }

    private var stepOptions: [StepOption] {
        switch currentStep {
        case .currentRHR:
            return [
                StepOption(
                    id: CurrentRHRBandQuestion.upTo60.id,
                    title: "≤ 60 bpm",
                    isSelected: viewModel.questionnaireCurrentRHRBand == .upTo60,
                    action: { viewModel.questionnaireCurrentRHRBand = .upTo60 }
                ),
                StepOption(
                    id: CurrentRHRBandQuestion.from61To75.id,
                    title: "61 – 75 bpm",
                    isSelected: viewModel.questionnaireCurrentRHRBand == .from61To75,
                    action: { viewModel.questionnaireCurrentRHRBand = .from61To75 }
                ),
                StepOption(
                    id: CurrentRHRBandQuestion.from76To90.id,
                    title: "76 – 90 bpm",
                    isSelected: viewModel.questionnaireCurrentRHRBand == .from76To90,
                    action: { viewModel.questionnaireCurrentRHRBand = .from76To90 }
                ),
                StepOption(
                    id: CurrentRHRBandQuestion.above90.id,
                    title: "≥ 90 bpm",
                    isSelected: viewModel.questionnaireCurrentRHRBand == .above90,
                    action: { viewModel.questionnaireCurrentRHRBand = .above90 }
                )
            ]
        case .weight:
            return []
        case .height:
            return []
        case .environment:
            return SportEnvironment.allCases.map { option in
                StepOption(
                    id: option.id,
                    title: option.displayName,
                    isSelected: viewModel.environment == option,
                    action: {
                        viewModel.environment = option
                    }
                )
            }
        case .preferredTime:
            return PreferredTime.allCases.map { option in
                StepOption(
                    id: option.id,
                    title: option.displayName,
                    isSelected: viewModel.preferredTime == option,
                    action: {
                        viewModel.preferredTime = option
                    }
                )
            }
        case .duration:
            return SessionDurationOption.allCases.map { option in
                StepOption(
                    id: option.id,
                    title: option.displayName,
                    isSelected: viewModel.sessionDuration == option,
                    action: {
                        viewModel.sessionDuration = option
                    }
                )
            }
        case .frequency:
            return [
                StepOption(
                    id: DaysPerWeekAvailability.twoToThree.id,
                    title: "2 – 3 days",
                    isSelected: viewModel.daysPerWeek == .twoToThree,
                    action: { viewModel.daysPerWeek = .twoToThree }
                ),
                StepOption(
                    id: DaysPerWeekAvailability.threeToFour.id,
                    title: "3 – 4 days",
                    isSelected: viewModel.daysPerWeek == .threeToFour,
                    action: { viewModel.daysPerWeek = .threeToFour }
                ),
                StepOption(
                    id: DaysPerWeekAvailability.fourToFive.id,
                    title: "4 – 5 days",
                    isSelected: viewModel.daysPerWeek == .fourToFive,
                    action: { viewModel.daysPerWeek = .fourToFive }
                ),
                StepOption(
                    id: DaysPerWeekAvailability.fiveToSeven.id,
                    title: "5 – 7 days",
                    isSelected: viewModel.daysPerWeek == .fiveToSeven,
                    action: { viewModel.daysPerWeek = .fiveToSeven }
                )
            ]
        case .equipment:
            return ExerciseAccessOptionQuestion.allCases.map { option in
                StepOption(
                    id: option.id,
                    title: option.displayName,
                    isSelected: viewModel.accessOptions.contains(option),
                    action: {
                        viewModel.toggleAccessOption(option)
                    }
                )
            }
        case .contraindications:
            return HealthConcernOption.allCases.map { option in
                StepOption(
                    id: option.id,
                    title: option.displayName,
                    isSelected: viewModel.healthConcerns.contains(option),
                    action: {
                        viewModel.toggleHealthConcern(option)
                    }
                )
            }
        case .targetRHR:
            return TargetRHRGoalQuestion.allCases.map { option in
                StepOption(
                    id: option.id,
                    title: option.displayName,
                    isSelected: viewModel.questionnaireTargetRHRGoal == option,
                    action: {
                        viewModel.questionnaireTargetRHRGoal = option
                    }
                )
            }
        }
    }

    private func handleBack() {
        inlineInputError = nil

        if currentStep == .currentRHR {
            onExitFromFirstQuestion()
            return
        }

        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousStep
    }

    private func handleNext() {
        inlineInputError = nil

        guard validateCurrentInputStep() else { return }

        if currentStep.isLast {
            viewModel.submitAndCompleteIfValid()
            return
        }

        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
    }

    private func maybePresentHealthKitPromptIfNeeded() {
        guard currentStep == .currentRHR else { return }
        guard !hasPresentedHealthKitPrompt else { return }
        hasPresentedHealthKitPrompt = true

        Task { @MainActor in
            let shouldPresent = await viewModel.shouldPresentHealthKitPrompt()
            guard shouldPresent else { return }
            guard currentStep == .currentRHR else { return }
            showHealthKitPrompt = true
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        VStack(spacing: 16) {
            switch currentStep {
            case .weight:
                numericInputCard(
                    placeholder: "Number input in kg",
                    unit: "kg",
                    text: $viewModel.weightKgText
                )
            case .height:
                numericInputCard(
                    placeholder: "Number input in cm",
                    unit: "cm",
                    text: $viewModel.heightCmText
                )
            default:
                VStack(spacing: 16) {
                    ForEach(stepOptions) { option in
                        optionRow(option)
                    }
                }
            }
        }
    }

    private func numericInputCard(
        placeholder: String,
        unit: String,
        text: Binding<String>
    ) -> some View {
        VStack(spacing: 16) {
            HStack {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)

                Spacer(minLength: 8)

                Text(unit)
                    .font(.headline)
                    .foregroundStyle(Color.slateGray)
                    .padding(.trailing, 24)
            }
            .glassEffect(.clear)
        }
    }

    private func optionRow(_ option: StepOption) -> some View {
        Button(action: option.action) {
            HStack(alignment: .center) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(Color.white)

                Spacer()

                ZStack {
                    if option.isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12).bold())
                            .foregroundStyle(.vibrantGreen)
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(
                    Circle()
                )
                .overlay(
                    Circle().stroke(option.isSelected ? Color.vibrantGreen : Color.white, lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticPressButtonStyle())
        .glassEffect(option.isSelected ? .clear.interactive() : .identity)
    }

    private func regexPattern(for kind: NumericInputKind) -> String {
        switch kind {
        case .weight:
            // 0-3 digit integer, optional decimal with max 1 digit (e.g. 70, 70.5, 120.0)
            return #"^[0-9]{0,3}(?:\.[0-9]{0,1})?$"#
        case .height:
            // Integer only, up to 3 digits (e.g. 165, 180)
            return #"^[0-9]{0,3}$"#
        }
    }

    private func normalizeInput(_ value: String, kind: NumericInputKind) -> String {
        switch kind {
        case .height:
            return value.filter(\.isNumber)
        case .weight:
            var result = ""
            var hasDecimalSeparator = false

            for character in value {
                if character.isNumber {
                    result.append(character)
                    continue
                }

                if character == "." || character == "," {
                    guard !hasDecimalSeparator else { continue }
                    hasDecimalSeparator = true
                    result.append(".")
                }
            }
            return result
        }
    }

    private func applyRegexGuard(for kind: NumericInputKind, newValue: String) {
        let normalized = normalizeInput(newValue, kind: kind)
        let isValid = normalized.range(of: regexPattern(for: kind), options: .regularExpression) != nil

        switch kind {
        case .weight:
            if isValid {
                if viewModel.weightKgText != normalized {
                    viewModel.weightKgText = normalized
                    return
                }
                lastValidWeightInput = normalized
            } else if viewModel.weightKgText != lastValidWeightInput {
                viewModel.weightKgText = lastValidWeightInput
            }
        case .height:
            if isValid {
                if viewModel.heightCmText != normalized {
                    viewModel.heightCmText = normalized
                    return
                }
                lastValidHeightInput = normalized
            } else if viewModel.heightCmText != lastValidHeightInput {
                viewModel.heightCmText = lastValidHeightInput
            }
        }
    }

    private func validateCurrentInputStep() -> Bool {
        switch currentStep {
        case .weight:
            guard let weight = Double(viewModel.weightKgText), weight > 0 else {
                inlineInputError = "Please input your weight in kg."
                return false
            }
            return true
        case .height:
            guard let height = Double(viewModel.heightCmText), height > 0 else {
                inlineInputError = "Please input your height in cm."
                return false
            }
            return true
        default:
            return true
        }
    }

}

@MainActor
private struct OnboardingPreviewHost: View {
    private let viewModel = PreviewSupport.makeOnboardingViewModel()

    var body: some View {
        NavigationStack {
            OnboardingView(viewModel: viewModel)
        }
    }
}

#Preview("Onboarding") {
    OnboardingPreviewHost()
}
