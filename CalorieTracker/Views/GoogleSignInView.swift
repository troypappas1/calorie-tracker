import SwiftUI

struct GoogleSignInView: View {
    @ObservedObject var auth: GoogleAuthService

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    EyebrowLabel(text: "Food Photo Nutrition")
                    Text("Track your meals,\nknow your nutrition.")
                        .font(.ctSerifBold(36))
                        .foregroundStyle(Color.ctText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Upload food photos or describe your meals to get an instant nutrition breakdown.")
                        .font(.ctSerif(16))
                        .foregroundStyle(Color.ctMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 16) {
                    Button {
                        Task { await auth.signIn() }
                    } label: {
                        HStack(spacing: 10) {
                            if auth.isSigningIn {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Continue with Google")
                                    .font(.ctSerif(17, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.ctAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.ctAccent.opacity(0.35), radius: 12, y: 4)
                    }
                    .disabled(auth.isSigningIn)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.ctSerif(13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(.ctSerif(12))
                        .foregroundStyle(Color.ctMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .ctPanel()

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}
