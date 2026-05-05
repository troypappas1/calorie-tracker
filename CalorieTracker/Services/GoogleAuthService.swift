import AuthenticationServices
import Foundation

// MARK: - Google user model

struct GoogleUser {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?
}

// MARK: - Auth service

@MainActor
final class GoogleAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var currentUser: GoogleUser?
    @Published var isSigningIn = false
    @Published var errorMessage: String?

    // Replace with your Google OAuth 2.0 client ID from console.cloud.google.com
    // After creating a project, go to APIs & Services > Credentials > Create OAuth Client ID > iOS
    static let clientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"

    // This must match the reversed client ID URL scheme added to Info.plist
    // e.g. com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID
    private static let redirectURI = "com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID:/oauth2callback"

    private static let scopes = "openid email profile"
    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private static let userInfoEndpoint = "https://www.googleapis.com/oauth2/v3/userinfo"

    private static let userKey = "google_user"

    override init() {
        super.init()
        loadSavedUser()
    }

    func signIn() async {
        guard !clientIDIsPlaceholder else {
            errorMessage = "Google Sign-In is not configured yet. Add your client ID in GoogleAuthService.swift."
            return
        }
        isSigningIn = true
        errorMessage = nil
        do {
            let code = try await fetchAuthCode()
            let token = try await exchangeCodeForToken(code)
            let user = try await fetchUserInfo(accessToken: token)
            currentUser = user
            saveUser(user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: Self.userKey)
    }

    // MARK: - Private

    private var clientIDIsPlaceholder: Bool {
        Self.clientID.hasPrefix("YOUR_GOOGLE_CLIENT_ID")
    }

    private func fetchAuthCode() async throws -> String {
        let state = UUID().uuidString
        var components = URLComponents(string: Self.authEndpoint)!
        components.queryItems = [
            .init(name: "client_id",     value: Self.clientID),
            .init(name: "redirect_uri",  value: Self.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: Self.scopes),
            .init(name: "state",         value: state),
        ]
        guard let url = components.url else { throw AuthError.badURL }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.redirectURI.components(separatedBy: ":").first
            ) { callbackURL, error in
                if let error { continuation.resume(throwing: error); return }
                guard let callbackURL,
                      let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: AuthError.missingCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }

    private func exchangeCodeForToken(_ code: String) async throws -> String {
        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code":          code,
            "client_id":     Self.clientID,
            "redirect_uri":  Self.redirectURI,
            "grant_type":    "authorization_code",
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String
        else { throw AuthError.tokenExchangeFailed }
        return accessToken
    }

    private func fetchUserInfo(accessToken: String) async throws -> GoogleUser {
        var request = URLRequest(url: URL(string: Self.userInfoEndpoint)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id    = json["sub"]    as? String,
              let email = json["email"]  as? String
        else { throw AuthError.userInfoFailed }
        let name = json["name"] as? String ?? email
        let avatar = (json["picture"] as? String).flatMap(URL.init)
        return GoogleUser(id: id, name: name, email: email, avatarURL: avatar)
    }

    private func saveUser(_ user: GoogleUser) {
        let dict: [String: String] = ["id": user.id, "name": user.name, "email": user.email, "avatar": user.avatarURL?.absoluteString ?? ""]
        UserDefaults.standard.set(dict, forKey: Self.userKey)
    }

    private func loadSavedUser() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.userKey) as? [String: String],
              let id    = dict["id"],
              let name  = dict["name"],
              let email = dict["email"]
        else { return }
        currentUser = GoogleUser(id: id, name: name, email: email, avatarURL: (dict["avatar"].flatMap(URL.init)))
    }

    // ASWebAuthenticationPresentationContextProviding
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    enum AuthError: LocalizedError {
        case badURL, missingCode, tokenExchangeFailed, userInfoFailed
        var errorDescription: String? {
            switch self {
            case .badURL:               return "Could not build the sign-in URL."
            case .missingCode:          return "No authorization code returned."
            case .tokenExchangeFailed:  return "Could not exchange code for token."
            case .userInfoFailed:       return "Could not fetch your Google profile."
            }
        }
    }
}
