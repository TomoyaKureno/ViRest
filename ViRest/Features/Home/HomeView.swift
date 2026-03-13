import SwiftUI

struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel
    @State private var checkInSheetVM: CheckInSheetViewModel?
    @State private var pendingConfirmSport: FirestoreSportEntry?

    init(viewModel: HomeViewModel) { self.viewModel = viewModel }

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        titleCard

                        if viewModel.isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else if viewModel.sports.isEmpty {
                            emptyCard
                        } else {
                            ForEach(viewModel.sports) { sport in
                                SportCheckInCard(sport: sport) {
                                    // Tap '+' → show confirmation first
                                    pendingConfirmSport = sport
                                }
                            }
                        }

                        if let msg = viewModel.checkInSuccess {
                            successBanner(msg)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("Weekly Plan")
            .toolbarTitleDisplayMode(.inline)
            .task { viewModel.load() }

            // ── Step 1: Confirmation alert
            .confirmationDialog(
                "Log a session?",
                isPresented: Binding(
                    get: { pendingConfirmSport != nil },
                    set: { if !$0 { pendingConfirmSport = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Yes, I completed this session") {
                    if let sport = pendingConfirmSport {
                        let vm = viewModel.makeCheckInSheetViewModel(for: sport)
                        checkInSheetVM = vm
                        pendingConfirmSport = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingConfirmSport = nil
                }
            } message: {
                if let sport = pendingConfirmSport {
                    Text("Did you complete a \(sport.displayName) session?")
                }
            }

            // ── Step 2: Check-in sheet (only opens after confirmation)
            .sheet(item: $checkInSheetVM) { vm in
                CheckInSheetView(viewModel: vm)
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

    // ── Title card
    private var titleCard: some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your title")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                    Text(viewModel.currentTitle.isEmpty ? "Rookie" : viewModel.currentTitle)
                        .font(AppTypography.hero(28))
                        .foregroundStyle(AppPalette.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.firestoreUser?.totalActionsCompleted ?? 0)")
                        .font(AppTypography.hero(28))
                        .foregroundStyle(AppPalette.accent)
                    Text("total sessions")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                }
            }
        }
    }

    private var emptyCard: some View {
        SurfaceCard {
            VStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36))
                    .foregroundStyle(AppPalette.accent)
                Text("No plan yet")
                    .font(AppTypography.title(20))
                    .foregroundStyle(AppPalette.textPrimary)
                Text("Complete onboarding to get your personalised sport recommendations.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(AppPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func successBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(msg).font(AppTypography.body(14)).foregroundStyle(.white)
            Spacer()
        }
        .padding(12)
        .background(Color.green.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.checkInSuccess = nil
            }
        }
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
