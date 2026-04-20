import UIKit

struct MockNutritionAnalyzer: NutritionAnalyzing {
    func analyze(image: UIImage) async throws -> NutritionEstimate {
        try await Task.sleep(for: .seconds(1))
        return mockEstimate(title: "Chicken Rice Bowl")
    }

    func analyze(description: String) async throws -> NutritionEstimate {
        try await Task.sleep(for: .seconds(1))
        return mockEstimate(title: description.isEmpty ? "Meal" : description)
    }

    private func mockEstimate(title: String) -> NutritionEstimate {
        NutritionEstimate(
            title: title,
            calories: 640,
            proteinGrams: 38,
            fatGrams: 14,
            carbsGrams: 72,
            fiberGrams: 4,
            sugarGrams: 3,
            sodiumMg: 620,
            vitaminA: 8,
            vitaminC: 12,
            calcium: 6,
            iron: 15,
            confidence: "Medium",
            notes: [
                "Mock result — add an API key in Settings for real analysis.",
                "Serving size and sauces can change the estimate significantly."
            ]
        )
    }
}
