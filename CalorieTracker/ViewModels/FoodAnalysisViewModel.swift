import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class FoodAnalysisViewModel: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var descriptionText: String = ""
    @Published var inputMode: InputMode = .photo
    @Published var estimate: NutritionEstimate?
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    @Published var isShowingCamera = false
    @Published var isShowingSettings = false

    enum InputMode {
        case photo, text
    }

    let mealLog = MealLog()

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

    func analyzeDescription() async {
        let text = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Enter a meal description first."
            return
        }
        isAnalyzing = true
        errorMessage = nil
        do {
            estimate = try await analyzer().analyze(description: text)
        } catch {
            errorMessage = error.localizedDescription
            estimate = nil
        }
        isAnalyzing = false
    }

    func logCurrentEstimate() {
        guard let estimate else { return }
        let thumbnail: Data? = inputMode == .photo ? selectedImage?.thumbnailData(maxSize: 80) : nil
        mealLog.add(estimate, thumbnail: thumbnail)
    }

    func saveConfiguration(provider: AppConfiguration.Provider, openAIKey: String, anthropicKey: String) {
        configuration = AppConfiguration(provider: provider, openAIKey: openAIKey, anthropicKey: anthropicKey)
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
        case .anthropic:
            return ClaudeNutritionAnalyzer(apiKey: configuration.anthropicKey)
        case .openAI:
            return OpenAINutritionAnalyzer(apiKey: configuration.openAIKey)
        }
    }
}
