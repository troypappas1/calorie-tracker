import SwiftUI

struct NutritionResultCard: View {
    let result: NutritionEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.title)
                .font(.title3.bold())

            HStack(spacing: 12) {
                metricCard(title: "Calories", value: "\(result.calories)")
                metricCard(title: "Protein", value: "\(result.proteinGrams)g")
            }

            Text("Confidence: \(result.confidence)")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.notes, id: \.self) { note in
                    Text("• \(note)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
