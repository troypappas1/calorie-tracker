import SwiftUI

@main
struct CalorieTrackerApp: App {
    @StateObject private var auth = GoogleAuthService()

    var body: some Scene {
        WindowGroup {
            if auth.currentUser != nil {
                ContentView()
                    .environmentObject(auth)
            } else {
                GoogleSignInView(auth: auth)
            }
        }
    }
}
