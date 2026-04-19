import UIKit

protocol NutritionAnalyzing {
    func analyze(image: UIImage) async throws -> NutritionEstimate
}
