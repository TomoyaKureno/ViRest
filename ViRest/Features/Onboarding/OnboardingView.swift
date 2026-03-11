import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            AppGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    heroSection
                    identitySection
                    healthSection
                    scheduleSection
                    environmentSection
                    preferenceSection
                    goalSection
                    disclaimerSection
                    submitSection
                }
                .padding(16)
                .padding(.bottom, 30)
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
                    Text("Build your 8-week plan")
                        .font(AppTypography.hero(30))
                        .foregroundStyle(AppPalette.textPrimary)
                    Text("ViRest combines your lifestyle inputs and Apple Health metrics to generate safer cardio recommendations.")
                        .font(AppTypography.body(15))
                        .foregroundStyle(AppPalette.textSecondary)
                }
            }
        }
    }

    private var identitySection: some View {
        SurfaceCard {
            sectionTitle("Profile", icon: "person.text.rectangle")

            fieldLabel("Full name")
            TextField("Full name", text: $viewModel.fullName)
                .textInputAutocapitalization(.words)
                .appFieldStyle()

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Age")
                    TextField("Age", text: $viewModel.ageText)
                        .keyboardType(.numberPad)
                        .appFieldStyle()
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Gender")
                    Picker("Gender", selection: $viewModel.gender) {
                        Text("Optional").tag(Gender?.none)
                        ForEach(Gender.allCases) { option in
                            Text(option.displayName).tag(Gender?.some(option))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
            }
        }
    }

    private var healthSection: some View {
        SurfaceCard {
            sectionTitle("Health & Safety", icon: "heart.circle")

            Button {
                viewModel.importHealthData()
            } label: {
                Label("Import from Apple Health", systemImage: "heart.text.square")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            if let snapshot = viewModel.importedHealthSnapshot {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Imported Metrics")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                    Text("RHR \(formatted(snapshot.restingHeartRate, suffix: "bpm")) · Height \(formatted(snapshot.heightCm, suffix: "cm")) · Weight \(formatted(snapshot.weightKg, suffix: "kg"))")
                        .font(AppTypography.body(14))
                        .foregroundStyle(AppPalette.textPrimary)
                }
                .padding(10)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            fieldLabel("Height and weight")
            HStack(spacing: 10) {
                TextField("Height (cm)", text: $viewModel.heightCmText)
                    .keyboardType(.decimalPad)
                    .appFieldStyle()

                TextField("Weight (kg)", text: $viewModel.weightKgText)
                    .keyboardType(.decimalPad)
                    .appFieldStyle()
            }

            fieldLabel("Current resting heart rate")
            Picker("Current Resting HR", selection: $viewModel.restingHeartRateRange) {
                ForEach(RestingHeartRateRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            Text("Health conditions")
                .font(AppTypography.caption(13))
                .foregroundStyle(AppPalette.textSecondary)

            chipFlow(HealthCondition.allCases, selected: $viewModel.healthConditions) { $0.displayName }

            fieldLabel("Injury limitation")
            Picker("Injury limitation", selection: $viewModel.injuryLimitation) {
                ForEach(InjuryLimitation.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private var scheduleSection: some View {
        SurfaceCard {
            sectionTitle("Time Constraints", icon: "clock.badge.checkmark")

            fieldLabel("How long can you exercise per session?")
            Picker("Duration per session", selection: $viewModel.sessionDuration) {
                ForEach(SessionDurationOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            fieldLabel("How many days per week are available?")
            Picker("Days available", selection: $viewModel.daysPerWeek) {
                ForEach(DaysPerWeekAvailability.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            fieldLabel("Preferred workout time")
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
            sectionTitle("Environment & Gear", icon: "figure.outdoor.cycle")

            fieldLabel("Preferred environment")
            Picker("Environment", selection: $viewModel.environment) {
                ForEach(SportEnvironment.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text("Available equipment")
                .font(AppTypography.caption(13))
                .foregroundStyle(AppPalette.textSecondary)

            chipFlow(Equipment.allCases, selected: $viewModel.equipments) { $0.displayName }
        }
    }

    private var preferenceSection: some View {
        SurfaceCard {
            sectionTitle("Sport Preferences", icon: "sparkles")

            Text("Enjoyable activities")
                .font(AppTypography.caption(13))
                .foregroundStyle(AppPalette.textSecondary)

            chipFlow(ActivityType.allCases, selected: $viewModel.enjoyableActivities) { $0.displayName }

            fieldLabel("Preferred intensity")
            Picker("Intensity", selection: $viewModel.intensityPreference) {
                ForEach(IntensityPreference.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            fieldLabel("Social mode")
            Picker("Social mode", selection: $viewModel.socialPreference) {
                ForEach(SocialPreference.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            fieldLabel("Exercise consistency")
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
            sectionTitle("Goals", icon: "target")

            fieldLabel("Target resting heart rate")
            Picker("Target Resting HR", selection: $viewModel.targetRestingHeartRateRange) {
                ForEach(RestingHeartRateRange.allCases.filter { $0 != .unknown }) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

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

    private var submitSection: some View {
        SurfaceCard {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.caption(12))
                    .foregroundStyle(.red.opacity(0.9))
            }

            Button {
                viewModel.submit()
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Generate Weekly Plan")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.isLoading)
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

    private func chipFlow<Option: Hashable>(_ options: [Option], selected: Binding<Set<Option>>, label: @escaping (Option) -> String) -> some View {
        let columns = [GridItem(.adaptive(minimum: 128), spacing: 9)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
            ForEach(Array(options.indices), id: \.self) { index in
                let option = options[index]
                SelectableChip(title: label(option), isSelected: selected.wrappedValue.contains(option)) {
                    if selected.wrappedValue.contains(option) {
                        selected.wrappedValue.remove(option)
                    } else {
                        selected.wrappedValue.insert(option)
                    }
                }
            }
        }
    }
}
