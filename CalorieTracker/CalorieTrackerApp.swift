import SwiftUI
import GoogleSignIn

@main
struct CalorieTrackerApp: App {
    @StateObject private var auth = GoogleAuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.currentUser != nil {
                    ContentView()
                        .environmentObject(auth)
                } else {
                    GoogleSignInView(auth: auth)
                }
            }
            .onOpenURL { url in
                auth.handle(url)
            }
        }
    }
}
