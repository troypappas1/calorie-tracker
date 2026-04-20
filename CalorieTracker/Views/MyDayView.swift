import SwiftUI

struct MyDayView: View {
    @ObservedObject var mealLog: MealLog

    var body: some View {
        NavigationStack {
            Group {
                if mealLog.todayEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            totalsCard
                            mealsSection
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Day")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No meals logged today")
                .font(.headline)
            Text("Scan a meal and tap \"Add to My Day\" to log it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalsCard: some View {
        let totals = mealLog.todayTotals
        return VStack(alignment: .leading, spacing: 16) {
            Text("Today's Totals")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                macroCell(title: "Calories", value: "\(totals.calories)")
                macroCell(title: "Protein", value: "\(totals.proteinGrams)g")
                macroCell(title: "Fat", value: "\(totals.fatGrams)g")
                macroCell(title: "Carbs", value: "\(totals.carbsGrams)g")
                macroCell(title: "Fiber", value: "\(totals.fiberGrams)g")
                macroCell(title: "Sugar", value: "\(totals.sugarGrams)g")
            }

            HStack {
                Text("Sodium")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totals.sodiumMg) mg")
                    .font(.subheadline.weight(.semibold))
            }

            Divider()

            VStack(spacing: 10) {
                microRow(name: "Vitamin A", percent: totals.vitaminA)
                microRow(name: "Vitamin C", percent: totals.vitaminC)
                microRow(name: "Calcium", percent: totals.calcium)
                microRow(name: "Iron", percent: totals.iron)
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meals")
                .font(.headline)

            ForEach(mealLog.todayEntries) { entry in
                mealRow(entry: entry)
            }
            .onDelete { offsets in
                mealLog.remove(at: offsets)
            }
        }
    }

    private func mealRow(entry: MealEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.estimate.title)
                    .font(.subheadline.weight(.semibold))
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.estimate.calories) cal")
                    .font(.subheadline.bold())
                Text("\(entry.estimate.proteinGrams)g protein")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func macroCell(title: String, value: String) -> some View {
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

    private func microRow(name: String, percent: Int) -> some View {
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
