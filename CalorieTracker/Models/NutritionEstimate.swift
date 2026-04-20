import Foundation

struct NutritionEstimate: Codable, Equatable {
    let title: String
    let calories: Int
    let proteinGrams: Int
    let fatGrams: Int
    let carbsGrams: Int
    let fiberGrams: Int
    let sugarGrams: Int
    let sodiumMg: Int
    let vitaminA: Int   // % Daily Value
    let vitaminC: Int
    let calcium: Int
    let iron: Int
    let confidence: String
    let notes: [String]
}
