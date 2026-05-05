import SwiftUI

struct WorkoutComingSoonView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 56))
                .foregroundStyle(Color.ctAccent)

            EyebrowLabel(text: "Coming Soon")

            Text("Workout Tracker")
                .font(.ctSerifBold(28))
                .foregroundStyle(Color.ctText)

            Text("Log workouts, track calories burned, and see how your activity balances with your nutrition.")
                .font(.ctSerif(16))
                .foregroundStyle(Color.ctMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .ctPanel()
    }
}
