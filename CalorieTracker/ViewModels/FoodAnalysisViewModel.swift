import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class FoodAnalysisViewModel: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var estimate: NutritionEstimate?
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    @Published var isShowingCamera = false
    @Published var isShowingSettings = false

    init(configuration: AppConfiguration = .load()) {
        self.configuration = configuration
    }

    func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        do {
            if let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
                estimate = nil
                errorMessage = nil
            }
        } catch {
            errorMessage = "The selected image could not be loaded."
        }
    }

    func analyzeSelectedImage() async {
        guard let selectedImage else {
            errorMessage = "Choose a photo first."
            return
        }

        isAnalyzing = true
        errorMessage = nil

        do {
            estimate = try await analyzer().analyze(image: selectedImage)
        } catch {
            errorMessage = error.localizedDescription
            estimate = nil
        }

        isAnalyzing = false
    }

    func saveConfiguration(provider: AppConfiguration.Provider, apiKey: String) {
        configuration = AppConfiguration(provider: provider, openAIKey: apiKey)
        configuration.save()
    }

    func setCapturedImage(_ image: UIImage?) {
        selectedImage = image
        estimate = nil
        errorMessage = nil
    }

    private func analyzer() -> NutritionAnalyzing {
        switch configuration.provider {
        case .mock:
            return MockNutritionAnalyzer()
        case .openAI:
            return OpenAINutritionAnalyzer(apiKey: configuration.openAIKey)
        }
    }
}
