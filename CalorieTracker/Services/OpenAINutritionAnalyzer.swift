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
        let requestBody = try makeRequestBody(imageDataURL: imageDataURL)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestBody

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionAnalyzerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw NutritionAnalyzerError.apiError(apiError?.error.message ?? "OpenAI request failed with status \(httpResponse.statusCode).")
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

    private func makeRequestBody(imageDataURL: String) throws -> Data {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "calories": ["type": "integer"],
                "proteinGrams": ["type": "integer"],
                "confidence": [
                    "type": "string",
                    "enum": ["Low", "Medium", "High"]
                ],
                "notes": [
                    "type": "array",
                    "items": ["type": "string"]
                ]
            ],
            "required": ["title", "calories", "proteinGrams", "confidence", "notes"],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": [[
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": """
                        Analyze this food image and estimate the likely dish name, calories, and protein in grams for the visible serving.
                        Return JSON only.
                        If the image is unclear, make your best estimate and lower confidence.
                        """
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
                    "schema": schema
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
            return "Add your OpenAI API key in Settings to use the OpenAI provider."
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
