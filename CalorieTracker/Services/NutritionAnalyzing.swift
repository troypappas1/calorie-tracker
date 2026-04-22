import UIKit

protocol NutritionAnalyzing {
    func analyze(image: UIImage) async throws -> NutritionEstimate
    func analyze(description: String) async throws -> NutritionEstimate
}

extension UIImage {
    func thumbnailData(maxSize: CGFloat) -> Data? {
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumb = renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        return thumb.jpegData(compressionQuality: 0.7)
    }
}
