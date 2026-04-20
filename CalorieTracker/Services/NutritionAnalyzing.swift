import UIKit

protocol NutritionAnalyzing {
    func analyze(image: UIImage) async throws -> NutritionEstimate
    func analyze(description: String) async throws -> NutritionEstimate
}
