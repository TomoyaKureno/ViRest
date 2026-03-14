import SwiftUI

struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel
    @State private var checkInSheetVM: CheckInSheetViewModel?
    @State private var pendingConfirmSport: FirestoreSportEntry?

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 16) {
                            ZStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.richBlack)
                                    .font(.largeTitle)
                            }
                            .padding()
                            .background(.gray)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.currentTitle.isEmpty ? "Starter" : viewModel.currentTitle)
                                    .font(AppTypography.caption(14))
                                    .foregroundStyle(AppPalette.textSecondary)

                                Text(viewModel.profileName)
                                    .font(AppTypography.hero(24))
                                    .foregroundStyle(AppPalette.textPrimary)
                            }
                        }

                        VStack {
                            HStack(spacing: 24) {
                                VStack(spacing: 6) {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.vibrantGreen)

                                        Text(viewModel.currentRestingHRText)
                                            .font(AppTypography.caption(16).bold())
                                            .foregroundStyle(AppPalette.textPrimary)
                                    }

                                    Text("Resting HR")
                                        .font(AppTypography.caption(14))
                                        .foregroundStyle(AppPalette.textPrimary)
                                }

                                Divider()
                                    .overlay(.vibrantGreen)

                                VStack(spacing: 6) {
                                    HStack {
                                        Image(systemName: "scalemass.fill")
                                            .foregroundStyle(.vibrantGreen)

                                        Text(viewModel.currentWeightText)
                                            .font(AppTypography.caption(16).bold())
                                            .foregroundStyle(AppPalette.textPrimary)
                                    }

                                    Text("Body Weight")
                                        .font(AppTypography.caption(14))
                                        .foregroundStyle(AppPalette.textPrimary)
                                }

                                Divider()
                                    .overlay(.vibrantGreen)

                                VStack(spacing: 6) {
                                    HStack {
                                        Image(systemName: "ruler.fill")
                                            .foregroundStyle(.vibrantGreen)
                                            .rotationEffect(.degrees(90))

                                        Text(viewModel.currentHeightText)
                                            .font(AppTypography.caption(16).bold())
                                            .foregroundStyle(AppPalette.textPrimary)
                                    }

                                    Text("Height")
                                        .font(AppTypography.caption(14))
                                        .foregroundStyle(AppPalette.textPrimary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }.frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading) {
                        Text("Sport Recommendations")
                            .font(AppTypography.hero(24))
                            .foregroundStyle(AppPalette.textPrimary)

                        if viewModel.isLoading {
                            ProgressView().tint(.white).padding(.top, 40)
                        } else if viewModel.sports.isEmpty {
                            emptyCard
                        } else {
                            VStack(spacing: 16) {
                                ForEach(viewModel.sports) { sport in
                                    SportCheckInCard(sport: sport) {
                                        pendingConfirmSport = sport
                                    }
                                }
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
            .background(.richBlack)
            .navigationTitle("Virest")
            .toolbarTitleDisplayMode(.inline)
            .task { viewModel.load() }
            .overlay {
                if let pendingSport = pendingConfirmSport {
                    ZStack {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()
                            .onTapGesture {
                                pendingConfirmSport = nil
                            }

                        activityConfirmationPopup(for: pendingSport)
                    }
                }
            }
            .sheet(item: $checkInSheetVM) { vm in
                CheckInSheetView(viewModel: vm)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func activityConfirmationPopup(for sport: FirestoreSportEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm Activity")
                .font(AppTypography.title(22))
                .foregroundStyle(.white)

            Text("Have you completed a \(sport.displayName) session?")
                .font(AppTypography.body(15))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 16) {
                Button {
                    let vm = viewModel.makeCheckInSheetViewModel(for: sport)
                    checkInSheetVM = vm
                    pendingConfirmSport = nil
                } label: {
                    Text("Yes, I completed this activity")
                        .font(AppTypography.body(15).bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppPalette.accent)
                        .clipShape(Capsule())
                }
                
                Button {
                    pendingConfirmSport = nil
                } label: {
                    Text("Cancel")
                        .font(AppTypography.body(15).bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: 360)
        .background(Color.richBlack.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var emptyCard: some View {
        SurfaceCard {
            VStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36))
                    .foregroundStyle(AppPalette.accent)
                Text("No sports recommended yet")
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
            firestoreUserRepository: seededContainer.firestoreUserRepository,
            userProfileRepository: seededContainer.userProfileRepository,
            authService: seededContainer.authService,
            healthService: seededContainer.healthService,
            notificationService: seededContainer.notificationService,
            gamificationService: seededContainer.gamificationService,
            badgeRepository: seededContainer.badgeStateRepository,
            planAdjustmentService: seededContainer.planAdjustmentService
        )
    }

    var body: some View {
        HomeView(viewModel: viewModel)
    }
}

#Preview("Home") {
    HomePreviewHost()
}
