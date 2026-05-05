import GoogleSignIn
import UIKit

@MainActor
final class GoogleAuthService: ObservableObject {
    @Published var currentUser: GIDGoogleUser?
    @Published var isSigningIn = false
    @Published var errorMessage: String?

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "823181249332-20gm4lmg5fnmj91tntavnd55bvt9bep5.apps.googleusercontent.com"
        )
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            Task { @MainActor [weak self] in
                self?.currentUser = user
            }
        }
    }

    func signIn() async {
        guard let rootVC = rootViewController else {
            errorMessage = "Could not present sign-in screen."
            return
        }
        isSigningIn = true
        errorMessage = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            currentUser = result.user
        } catch {
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
        isSigningIn = false
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
    }

    func handle(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
