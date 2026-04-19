import Foundation

struct NutritionEstimate: Codable, Equatable {
    let title: String
    let calories: Int
    let proteinGrams: Int
    let confidence: String
    let notes: [String]
}
