import UIKit

struct MockNutritionAnalyzer: NutritionAnalyzing {
    func analyze(image: UIImage) async throws -> NutritionEstimate {
        try await Task.sleep(for: .seconds(1))

        return NutritionEstimate(
            title: "Chicken rice bowl",
            calories: 640,
            proteinGrams: 38,
            confidence: "Medium",
            notes: [
                "Estimate assumes a single serving.",
                "Rice and sauce amount can shift calories significantly."
            ]
        )
    }
}
