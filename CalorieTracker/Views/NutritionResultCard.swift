import SwiftUI

struct NutritionResultCard: View {
    let result: NutritionEstimate
    let onLog: (() -> Void)?
    @State private var logged = false

    init(result: NutritionEstimate, onLog: (() -> Void)? = nil) {
        self.result = result
        self.onLog = onLog
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel(text: "Estimate")
                    Text(result.title)
                        .font(.ctSerifBold(22))
                        .foregroundStyle(Color.ctText)
                }
                Spacer()
                Text("Claude")
                    .font(.ctSerif(13, weight: .bold))
                    .foregroundStyle(Color.ctAccentDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.ctAccent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 20)

            // Macros grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricCard("Calories", value: "\(result.calories)")
                metricCard("Protein",  value: "\(result.proteinGrams)g")
                metricCard("Fat",      value: "\(result.fatGrams)g")
                metricCard("Carbs",    value: "\(result.carbsGrams)g")
                metricCard("Fiber",    value: "\(result.fiberGrams)g")
                metricCard("Sugar",    value: "\(result.sugarGrams)g")
            }

            // Sodium
            HStack {
                Text("Sodium")
                    .font(.ctSerif(14))
                    .foregroundStyle(Color.ctMuted)
                Spacer()
                Text("\(result.sodiumMg) mg")
                    .font(.ctSerif(15, weight: .bold))
                    .foregroundStyle(Color.ctText)
            }
            .padding(.top, 10)
            .padding(.bottom, 20)

            // Vitamins & Minerals
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Vitamins & Minerals")
                        .font(.ctSerif(15, weight: .bold))
                        .foregroundStyle(Color.ctText)
                    Text("% Daily Value")
                        .font(.ctSerif(12))
                        .foregroundStyle(Color.ctMuted)
                }
                VStack(spacing: 10) {
                    VitaminRow(name: "Vitamin A", percent: result.vitaminA)
                    VitaminRow(name: "Vitamin C", percent: result.vitaminC)
                    VitaminRow(name: "Calcium",   percent: result.calcium)
                    VitaminRow(name: "Iron",      percent: result.iron)
                }
            }
            .padding(.bottom, 20)

            // Confidence
            Divider().background(Color.ctLine)
            HStack {
                Text("Confidence")
                    .font(.ctSerif(14))
                    .foregroundStyle(Color.ctMuted)
                Spacer()
                Text(result.confidence)
                    .font(.ctSerif(14, weight: .bold))
                    .foregroundStyle(Color.ctText)
            }
            .padding(.vertical, 16)
            Divider().background(Color.ctLine)

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.ctSerif(15, weight: .bold))
                    .foregroundStyle(Color.ctText)
                    .padding(.top, 16)
                ForEach(result.notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Color.ctMuted)
                        Text(note).font(.ctSerif(14)).foregroundStyle(Color.ctMuted)
                    }
                }
            }

            // Add to My Day
            if let onLog {
                Divider().background(Color.ctLine).padding(.top, 20)
                Button {
                    onLog()
                    logged = true
                } label: {
                    Text(logged ? "Added!" : "+ Add to My Day")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(logged)
                .padding(.top, 20)
            }
        }
        .padding(24)
        .ctPanel()
        .onChange(of: result.title) { _, _ in logged = false }
    }

    private func metricCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.ctSerif(13))
                .foregroundStyle(Color.ctMuted)
            Text(value)
                .font(.ctSerifBold(28))
                .foregroundStyle(Color.ctText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ctLine, lineWidth: 1))
    }
}
