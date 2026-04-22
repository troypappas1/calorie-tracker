import Foundation

struct MealEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let estimate: NutritionEstimate
    var thumbnailData: Data?
}

struct NutritionTotals {
    let calories: Int
    let proteinGrams: Int
    let fatGrams: Int
    let carbsGrams: Int
    let fiberGrams: Int
    let sugarGrams: Int
    let sodiumMg: Int
    let vitaminA: Int
    let vitaminC: Int
    let calcium: Int
    let iron: Int

    init(entries: [NutritionEstimate]) {
        calories = entries.reduce(0) { $0 + $1.calories }
        proteinGrams = entries.reduce(0) { $0 + $1.proteinGrams }
        fatGrams = entries.reduce(0) { $0 + $1.fatGrams }
        carbsGrams = entries.reduce(0) { $0 + $1.carbsGrams }
        fiberGrams = entries.reduce(0) { $0 + $1.fiberGrams }
        sugarGrams = entries.reduce(0) { $0 + $1.sugarGrams }
        sodiumMg = entries.reduce(0) { $0 + $1.sodiumMg }
        vitaminA = entries.reduce(0) { $0 + $1.vitaminA }
        vitaminC = entries.reduce(0) { $0 + $1.vitaminC }
        calcium = entries.reduce(0) { $0 + $1.calcium }
        iron = entries.reduce(0) { $0 + $1.iron }
    }
}

final class MealLog: ObservableObject {
    @Published private(set) var entries: [MealEntry] = []

    private static let storageKey = "app.meallog"

    init() {
        load()
    }

    func add(_ estimate: NutritionEstimate, thumbnail: Data? = nil) {
        let entry = MealEntry(id: UUID(), date: Date(), estimate: estimate, thumbnailData: thumbnail)
        entries.append(entry)
        save()
    }

    func clearToday() {
        let today = Calendar.current.startOfDay(for: Date())
        entries.removeAll { Calendar.current.startOfDay(for: $0.date) == today }
        save()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    var todayEntries: [MealEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayTotals: NutritionTotals {
        NutritionTotals(entries: todayEntries.map(\.estimate))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([MealEntry].self, from: data) else { return }
        entries = decoded
    }
}
