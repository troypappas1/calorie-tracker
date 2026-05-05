import SwiftUI

struct WorkoutComingSoonView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "figure.run.circle")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(Color.ctAccent)

            VStack(spacing: 10) {
                Text("Workout Tracker")
                    .font(.title.bold())
                Text("Coming Soon")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.ctAccent)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "video.badge.checkmark", title: "Form Analysis", desc: "Upload a workout video and get AI feedback on your form and technique.")
                featureRow(icon: "chart.line.uptrend.xyaxis", title: "Custom Workout Plans", desc: "Get a personalized plan based on your goals — fat loss, muscle gain, definition, or hypertrophy.")
                featureRow(icon: "scalemass", title: "Goal Tracking", desc: "Set your current weight, target weight, and timeline. Track your progress over time.")
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.ctAccent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundStyle(.secondary).lineSpacing(2)
            }
        }
    }
}
