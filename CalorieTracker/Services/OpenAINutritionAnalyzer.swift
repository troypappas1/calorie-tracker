import Foundation
import UIKit

struct OpenAINutritionAnalyzer: NutritionAnalyzing {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func analyze(image: UIImage) async throws -> NutritionEstimate {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NutritionAnalyzerError.missingAPIKey
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NutritionAnalyzerError.invalidImageData
        }

        let imageDataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        let body = try makeImageRequestBody(imageDataURL: imageDataURL)
        return try await performRequest(body)
    }

    func analyze(description: String) async throws -> NutritionEstimate {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NutritionAnalyzerError.missingAPIKey
        }

        let body = try makeTextRequestBody(description: description)
        return try await performRequest(body)
    }

    private func performRequest(_ body: Data) async throws -> NutritionEstimate {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionAnalyzerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw NutritionAnalyzerError.apiError(
                apiError?.error.message ?? "OpenAI request failed with status \(httpResponse.statusCode)."
            )
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let jsonText = decoded.outputText, let payload = jsonText.data(using: .utf8) else {
            throw NutritionAnalyzerError.missingOutput
        }

        do {
            return try JSONDecoder().decode(NutritionEstimate.self, from: payload)
        } catch {
            throw NutritionAnalyzerError.decodingFailed
        }
    }

    private func makeSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "calories": ["type": "integer"],
                "proteinGrams": ["type": "integer"],
                "fatGrams": ["type": "integer"],
                "carbsGrams": ["type": "integer"],
                "fiberGrams": ["type": "integer"],
                "sugarGrams": ["type": "integer"],
                "sodiumMg": ["type": "integer"],
                "vitaminA": ["type": "integer"],
                "vitaminC": ["type": "integer"],
                "calcium": ["type": "integer"],
                "iron": ["type": "integer"],
                "confidence": ["type": "string", "enum": ["Low", "Medium", "High"]],
                "notes": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["title", "calories", "proteinGrams", "fatGrams", "carbsGrams",
                         "fiberGrams", "sugarGrams", "sodiumMg", "vitaminA", "vitaminC",
                         "calcium", "iron", "confidence", "notes"],
            "additionalProperties": false
        ]
    }

    private func makeImageRequestBody(imageDataURL: String) throws -> Data {
        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": [[
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": "Analyze this food image and estimate the nutrition for the visible serving size. Return JSON only. If unclear, make your best estimate and lower confidence."
                    ],
                    [
                        "type": "input_image",
                        "image_url": imageDataURL,
                        "detail": "high"
                    ]
                ]
            ]],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "nutrition_estimate",
                    "strict": true,
                    "schema": makeSchema()
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [])
    }

    private func makeTextRequestBody(description: String) throws -> Data {
        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": [[
                "role": "user",
                "content": [[
                    "type": "input_text",
                    "text": "You are a nutrition expert. The user describes a meal: \"\(description)\"\n\nEstimate the nutrition for this meal. Return JSON only."
                ]]
            ]],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "nutrition_estimate",
                    "strict": true,
                    "schema": makeSchema()
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [])
    }
}

enum NutritionAnalyzerError: LocalizedError {
    case missingAPIKey
    case invalidImageData
    case invalidResponse
    case apiError(String)
    case missingOutput
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an API key in Settings to use this provider."
        case .invalidImageData:
            return "The selected image could not be prepared for upload."
        case .invalidResponse:
            return "The server response could not be read."
        case .apiError(let message):
            return message
        case .missingOutput:
            return "No structured nutrition output was returned."
        case .decodingFailed:
            return "The returned nutrition estimate could not be decoded."
        }
    }
}

private struct OpenAIResponse: Decodable {
    let outputText: String?
    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
    }
}

private struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}
