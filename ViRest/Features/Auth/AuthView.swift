import SwiftUI

struct AuthView: View {
    @ObservedObject private var viewModel: AuthViewModel

    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(alignment: .leading, spacing: 20) {
                heroSection

                SurfaceCard {
                    Text("Welcome back")
                        .font(AppTypography.title(24))
                        .foregroundStyle(AppPalette.textPrimary)

                    Text("Start with secure sign-in, then ViRest will personalize your sport plan from onboarding input and Apple Health data.")
                        .font(AppTypography.body(15))
                        .foregroundStyle(AppPalette.textSecondary)

                    Button {
                        viewModel.signInWithApple()
                    } label: {
                        Label("Continue with Apple", systemImage: "apple.logo")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        viewModel.signInWithGoogle()
                    } label: {
                        Label("Continue with Google", systemImage: "globe")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Divider().overlay(.white.opacity(0.12))

//                    Text("— Or test with separate buttons —")
//                        .font(AppTypography.caption(12))
//                        .foregroundStyle(AppPalette.textSecondary)
//                        .frame(maxWidth: .infinity, alignment: .center)
//
//                    Button {
//                        viewModel.testSignInWithApple()
//                    } label: {
//                        Label("Test Sign in with Apple (Firebase)", systemImage: "apple.logo")
//                    }
//                    .buttonStyle(SecondaryActionButtonStyle())
//
//                    Button {
//                        viewModel.testSignInWithGoogle()
//                    } label: {
//                        Label("Test Sign in with Google (Firebase)", systemImage: "globe")
//                    }
//                    .buttonStyle(SecondaryActionButtonStyle())

                    Text("Firebase-compatible auth flow is prepared. Attach SDK keys for production login.")
                        .font(AppTypography.caption(12))
                        .foregroundStyle(AppPalette.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption(13))
                        .foregroundStyle(.red.opacity(0.9))
                }

                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Signing in...")
                            .font(AppTypography.caption(13))
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(
                            colors: [AppPalette.auroraA, AppPalette.auroraB],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("ViRest")
                    .font(AppTypography.hero(40))
                    .foregroundStyle(AppPalette.textPrimary)
            }

            Text("Modern cardio guidance to improve your resting heart rate, safely and consistently.")
                .font(AppTypography.body(16))
                .foregroundStyle(AppPalette.textSecondary)
        }
    }
}

