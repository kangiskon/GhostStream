import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var accountStore: AccountStore

    @State private var email = ""
    @State private var password = ""
    @State private var showResetConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 7/255, green: 7/255, blue: 13/255),
                    Color(red: 20/255, green: 11/255, blue: 36/255),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 36)

                    VStack(spacing: 10) {
                        Image(systemName: "play.rectangle.on.rectangle.fill")
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundStyle(Theme.accentBright)
                            .shadow(color: Theme.accent.opacity(0.65), radius: 24)
                        Text("GHOSTSTREAM")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .tracking(3)
                        Text("Your personal streaming command center")
                            .foregroundStyle(Theme.muted)
                    }

                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .ghostAuthField()

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .ghostAuthField()

                        Button("Sign In") {
                            Task { await accountStore.signIn(email: email, password: password) }
                        }
                        .buttonStyle(GhostPrimaryButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty)

                        Button("Create Account") {
                            Task { await accountStore.register(email: email, password: password) }
                        }
                        .buttonStyle(GhostSecondaryButtonStyle())
                        .disabled(email.isEmpty || password.count < 12)

                        Button("Forgot Password") {
                            Task {
                                await accountStore.requestPasswordReset(email: email)
                                showResetConfirmation = true
                            }
                        }
                        .foregroundStyle(Theme.accentBright)
                        .disabled(email.isEmpty)

                        HStack {
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                            Text("OR").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        }

                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task {
                                do {
                                    let payload = try AppleSignInCoordinator.payload(from: result)
                                    await accountStore.signInWithApple(
                                        identityToken: payload.identityToken,
                                        authorizationCode: payload.authorizationCode
                                    )
                                } catch {
                                    // The native sheet already reports cancellations; keep the screen available.
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(22)
                    .background(Theme.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                    statusView
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 22)
                .padding(.bottom, 44)
            }
        }
        .alert("Password reset", isPresented: $showResetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("If an account exists for that email, GhostStream will send password reset instructions.")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch accountStore.status {
        case .working, .restoring:
            ProgressView()
                .tint(Theme.accentBright)
        case .awaitingEmailVerification(let email):
            Text("Check \(email) for the GhostStream verification link, then return here and sign in.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
        case .error(let message):
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.red.opacity(0.9))
        default:
            EmptyView()
        }
    }
}

private extension View {
    func ghostAuthField() -> some View {
        self
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )
    }
}

private struct GhostPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct GhostSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(Color.white.opacity(configuration.isPressed ? 0.05 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
