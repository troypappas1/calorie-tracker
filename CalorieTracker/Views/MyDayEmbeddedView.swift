import SwiftUI

// Inline My Day used inside the main scroll view (no NavigationStack wrapper)
struct MyDayEmbeddedView: View {
    @ObservedObject var mealLog: MealLog
    @State private var showingClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowLabel(text: "Calorie Tracker")
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.ctSerif(13))
                        .foregroundStyle(Color.ctMuted)
                }
                Spacer()
                if !mealLog.todayEntries.isEmpty {
                    Button("Clear Day") { showingClearConfirm = true }
                        .font(.ctSerif(13, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            if mealLog.todayEntries.isEmpty {
                emptyState
            } else {
                totalsCard
                Text("Meals")
                    .font(.ctSerifBold(20))
                    .foregroundStyle(Color.ctText)
                ForEach(mealLog.todayEntries) { entry in
                    entryCard(entry: entry)
                }
            }
        }
        .confirmationDialog("Clear all meals for today?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("Clear Day", role: .destructive) { mealLog.clearToday() }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundStyle(Color.ctAccent)
            Text("No meals logged today")
                .font(.ctSerifBold(18))
                .foregroundStyle(Color.ctText)
            Text("Analyze a meal and tap \"Add to My Day\" to log it here.")
                .font(.ctSerif(15))
                .foregroundStyle(Color.ctMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .ctPanel()
    }

    // MARK: - Totals card

    private var totalsCard: some View {
        let t = mealLog.todayTotals
        return VStack(alignment: .leading, spacing: 16) {
            Text("Today's Totals")
                .font(.ctSerifBold(18))
                .foregroundStyle(Color.ctText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                macroCell("Calories", value: "\(t.calories)")
                macroCell("Protein",  value: "\(t.proteinGrams)g")
                macroCell("Fat",      value: "\(t.fatGrams)g")
                macroCell("Carbs",    value: "\(t.carbsGrams)g")
                macroCell("Fiber",    value: "\(t.fiberGrams)g")
                macroCell("Sugar",    value: "\(t.sugarGrams)g")
            }

            sodiumRow(t.sodiumMg)

            Divider().background(Color.ctLine)

            VStack(alignment: .leading, spacing: 6) {
                Text("Vitamins & Minerals")
                    .font(.ctSerif(13, weight: .bold))
                    .foregroundStyle(Color.ctAccentDark)
                Text("% Daily Value (cumulative)")
                    .font(.ctSerif(11))
                    .foregroundStyle(Color.ctMuted)
            }
            VStack(spacing: 10) {
                VitaminRow(name: "Vitamin A", percent: t.vitaminA)
                VitaminRow(name: "Vitamin C", percent: t.vitaminC)
                VitaminRow(name: "Calcium",   percent: t.calcium)
                VitaminRow(name: "Iron",      percent: t.iron)
            }
        }
        .padding(20)
        .ctPanel()
    }

    // MARK: - Entry card

    private func entryCard(entry: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let data = entry.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.ctAccent.opacity(0.1))
                            .frame(width: 64, height: 64)
                        Text("🍽️").font(.title2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.estimate.title)
                        .font(.ctSerif(16, weight: .bold))
                        .foregroundStyle(Color.ctText)
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.ctSerif(13))
                        .foregroundStyle(Color.ctMuted)
                }

                Spacer()

                Button {
                    if let idx = mealLog.entries.firstIndex(where: { $0.id == entry.id }) {
                        mealLog.remove(at: IndexSet(integer: idx))
                    }
                } label: {
                    Text("✕ Remove")
                        .font(.ctSerif(13, weight: .bold))
                        .foregroundStyle(Color.ctMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.ctMuted.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                entryMacro("Calories", "\(entry.estimate.calories)")
                entryMacro("Protein",  "\(entry.estimate.proteinGrams)g")
                entryMacro("Fat",      "\(entry.estimate.fatGrams)g")
                entryMacro("Carbs",    "\(entry.estimate.carbsGrams)g")
                entryMacro("Fiber",    "\(entry.estimate.fiberGrams)g")
                entryMacro("Sugar",    "\(entry.estimate.sugarGrams)g")
                entryMacro("Sodium",   "\(entry.estimate.sodiumMg)mg")
            }

            Divider().background(Color.ctLine)

            VStack(spacing: 8) {
                VitaminRow(name: "Vitamin A", percent: entry.estimate.vitaminA)
                VitaminRow(name: "Vitamin C", percent: entry.estimate.vitaminC)
                VitaminRow(name: "Calcium",   percent: entry.estimate.calcium)
                VitaminRow(name: "Iron",      percent: entry.estimate.iron)
            }
        }
        .padding(20)
        .ctPanel()
    }

    // MARK: - Helpers

    private func macroCell(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.ctSerif(12))
                .foregroundStyle(Color.ctMuted)
            Text(value)
                .font(.ctSerifBold(22))
                .foregroundStyle(Color.ctText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.ctLine, lineWidth: 1))
    }

    private func entryMacro(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.ctSerif(10))
                .foregroundStyle(Color.ctMuted)
                .textCase(.uppercase)
                .kerning(0.8)
            Text(value)
                .font(.ctSerif(15, weight: .bold))
                .foregroundStyle(Color.ctText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ctLine, lineWidth: 1))
    }

    private func sodiumRow(_ mg: Int) -> some View {
        HStack {
            Text("Sodium")
                .font(.ctSerif(15))
                .foregroundStyle(Color.ctMuted)
            Spacer()
            Text("\(mg) mg")
                .font(.ctSerif(15, weight: .bold))
                .foregroundStyle(Color.ctText)
        }
    }
}
