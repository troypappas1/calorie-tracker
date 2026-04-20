import Foundation
import UIKit

struct ClaudeNutritionAnalyzer: NutritionAnalyzing {
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

        let base64 = imageData.base64EncodedString()
        let payload: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 600,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    ["type": "text", "text": promptText()]
                ]
            ]]
        ]
        return try await callClaude(payload: payload)
    }

    func analyze(description: String) async throws -> NutritionEstimate {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NutritionAnalyzerError.missingAPIKey
        }

        let payload: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 600,
            "messages": [[
                "role": "user",
                "content": "You are a nutrition expert. The user describes a meal: \"\(description)\"\n\nEstimate the nutrition for this meal. \(promptText())"
            ]]
        ]
        return try await callClaude(payload: payload)
    }

    private func promptText() -> String {
        """
        You are a nutrition expert. Identify the food(s) and estimate nutrition for the visible serving size.
        Reply with ONLY a JSON object:
        {"title": "dish name", "calories": 550, "proteinGrams": 25, "fatGrams": 18, "carbsGrams": 60, "fiberGrams": 5, "sugarGrams": 8, "sodiumMg": 450, "vitaminA": 15, "vitaminC": 20, "calcium": 10, "iron": 8, "confidence": "High", "notes": ["short helpful note"]}
        vitaminA, vitaminC, calcium, iron are % Daily Value as integers. confidence must be Low, Medium, or High.
        """
    }

    private func callClaude(payload: [String: Any]) async throws -> NutritionEstimate {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionAnalyzerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data)
            throw NutritionAnalyzerError.apiError(
                apiError?.error.message ?? "Claude request failed with status \(httpResponse.statusCode)."
            )
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first?.text else {
            throw NutritionAnalyzerError.missingOutput
        }

        let jsonText = extractJSON(from: text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NutritionAnalyzerError.decodingFailed
        }

        do {
            return try JSONDecoder().decode(NutritionEstimate.self, from: jsonData)
        } catch {
            throw NutritionAnalyzerError.decodingFailed
        }
    }

    private func extractJSON(from text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            let lines = t.split(separator: "\n", omittingEmptySubsequences: false)
            t = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}") else { return t }
        return String(t[start...end])
    }
}

private struct ClaudeResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }
    let content: [Content]
}

private struct ClaudeErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}
