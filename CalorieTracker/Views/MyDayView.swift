import SwiftUI

struct MyDayView: View {
    @ObservedObject var mealLog: MealLog
    @State private var showingClearConfirm = false

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
            .toolbar {
                if !mealLog.todayEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear Day", role: .destructive) {
                            showingClearConfirm = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog("Clear all meals for today?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("Clear Day", role: .destructive) {
                    mealLog.clearToday()
                }
            }
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
                entryCard(entry: entry)
            }
        }
    }

    private func entryCard(entry: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let data = entry.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemFill))
                            .frame(width: 56, height: 56)
                        Text("🍽️")
                            .font(.title2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.estimate.title)
                        .font(.subheadline.weight(.semibold))
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if let idx = mealLog.entries.firstIndex(where: { $0.id == entry.id }) {
                        mealLog.remove(at: IndexSet(integer: idx))
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                entryMacroCell(title: "Calories", value: "\(entry.estimate.calories)")
                entryMacroCell(title: "Protein", value: "\(entry.estimate.proteinGrams)g")
                entryMacroCell(title: "Fat", value: "\(entry.estimate.fatGrams)g")
                entryMacroCell(title: "Carbs", value: "\(entry.estimate.carbsGrams)g")
                entryMacroCell(title: "Fiber", value: "\(entry.estimate.fiberGrams)g")
                entryMacroCell(title: "Sugar", value: "\(entry.estimate.sugarGrams)g")
            }

            HStack {
                Text("Sodium")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.estimate.sodiumMg) mg")
                    .font(.caption.weight(.semibold))
            }

            Divider()

            VStack(spacing: 8) {
                microRow(name: "Vitamin A", percent: entry.estimate.vitaminA)
                microRow(name: "Vitamin C", percent: entry.estimate.vitaminC)
                microRow(name: "Calcium", percent: entry.estimate.calcium)
                microRow(name: "Iron", percent: entry.estimate.iron)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func entryMacroCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
