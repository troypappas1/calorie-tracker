import SwiftUI

struct NutritionResultCard: View {
    let result: NutritionEstimate
    let onLog: (() -> Void)?

    init(result: NutritionEstimate, onLog: (() -> Void)? = nil) {
        self.result = result
        self.onLog = onLog
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.title)
                .font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricCard(title: "Calories", value: "\(result.calories)")
                metricCard(title: "Protein", value: "\(result.proteinGrams)g")
                metricCard(title: "Fat", value: "\(result.fatGrams)g")
                metricCard(title: "Carbs", value: "\(result.carbsGrams)g")
                metricCard(title: "Fiber", value: "\(result.fiberGrams)g")
                metricCard(title: "Sugar", value: "\(result.sugarGrams)g")
            }

            HStack {
                Text("Sodium")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(result.sodiumMg) mg")
                    .font(.subheadline.weight(.semibold))
            }

            Divider()

            VStack(spacing: 10) {
                micronutrientRow(name: "Vitamin A", percent: result.vitaminA)
                micronutrientRow(name: "Vitamin C", percent: result.vitaminC)
                micronutrientRow(name: "Calcium", percent: result.calcium)
                micronutrientRow(name: "Iron", percent: result.iron)
            }

            Divider()

            Text("Confidence: \(result.confidence)")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(result.notes, id: \.self) { note in
                    Text("• \(note)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let onLog {
                Button(action: onLog) {
                    Label("Add to My Day", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
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

    private func micronutrientRow(name: String, percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percent)% DV")
                    .font(.caption.weight(.semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * min(CGFloat(percent) / 100.0, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
