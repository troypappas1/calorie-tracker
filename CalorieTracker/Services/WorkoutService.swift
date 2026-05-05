import Foundation
import UIKit

struct WorkoutService {
    private let apiKey = Secrets.claudeAPIKey

    // MARK: - Generate workout plan

    func generatePlan(profile: WorkoutProfile) async throws -> String {
        let weightInfo: String
        if !profile.currentWeightLbs.isEmpty && !profile.targetWeightLbs.isEmpty {
            weightInfo = "Current weight: \(profile.currentWeightLbs) lbs. Target weight: \(profile.targetWeightLbs) lbs."
        } else if !profile.currentWeightLbs.isEmpty {
            weightInfo = "Current weight: \(profile.currentWeightLbs) lbs."
        } else {
            weightInfo = ""
        }

        let timelineInfo = profile.timelineWeeks.isEmpty ? "" : "Timeline: \(profile.timelineWeeks) weeks."
        let notesInfo = profile.notes.isEmpty ? "" : "Additional notes: \(profile.notes)"

        let prompt = """
        You are an expert personal trainer and exercise scientist. Create a detailed, personalized workout plan.

        Client profile:
        - Goal: \(profile.goal.displayName)
        - Fitness level: \(profile.fitnessLevel.displayName)
        - Training days per week: \(profile.daysPerWeek.rawValue)
        - Equipment: \(profile.equipment)
        \(weightInfo)
        \(timelineInfo)
        \(notesInfo)

        Provide a comprehensive workout plan that includes:
        1. A brief overview and strategy for achieving their goal
        2. A weekly training split (which muscle groups on which days)
        3. For each training day: specific exercises, sets, reps, and rest periods
        4. Key principles for their goal (e.g. progressive overload for hypertrophy, caloric deficit tips for fat loss)
        5. Recovery and nutrition notes relevant to their goal

        Be very specific with rep ranges, set counts, and tempo where relevant. For hypertrophy, include details about time under tension. For fat loss, include cardio recommendations. Format clearly with headers and bullet points.
        """

        let payload: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 2000,
            "messages": [["role": "user", "content": prompt]]
        ]

        return try await callClaude(payload: payload)
    }

    // MARK: - Analyze form from image frames

    func analyzeForm(frames: [UIImage], exerciseName: String) async throws -> FormAnalysisResult {
        guard !frames.isEmpty else { throw WorkoutError.noFrames }

        var imageContent: [[String: Any]] = []

        for (i, frame) in frames.prefix(4).enumerated() {
            guard let data = frame.jpegData(compressionQuality: 0.7) else { continue }
            let base64 = data.base64EncodedString()
            imageContent.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]
            ])
            imageContent.append([
                "type": "text",
                "text": "Frame \(i + 1):"
            ])
        }

        let exerciseText = exerciseName.isEmpty ? "the exercise shown" : exerciseName

        imageContent.append([
            "type": "text",
            "text": """
            Analyze the form for \(exerciseText) shown in these frames.

            Reply with ONLY a JSON object:
            {
              "exercise": "exercise name",
              "overallScore": "Good/Needs Work/Excellent",
              "strengths": ["point 1", "point 2"],
              "improvements": ["improvement 1", "improvement 2"],
              "safetyNotes": ["safety note if any"],
              "tips": "one key coaching tip"
            }
            """
        ])

        let payload: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 600,
            "messages": [["role": "user", "content": imageContent]]
        ]

        let responseText = try await callClaude(payload: payload)
        return try parseFormResult(responseText)
    }

    // MARK: - Private helpers

    private func callClaude(payload: [String: Any]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WorkoutError.apiError
        }

        let decoded = try JSONDecoder().decode(ClaudeMessageResponse.self, from: data)
        guard let text = decoded.content.first?.text else { throw WorkoutError.noResponse }
        return text
    }

    private func parseFormResult(_ text: String) throws -> FormAnalysisResult {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.split(separator: "\n").dropFirst().dropLast().joined(separator: "\n")
        }
        guard let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}") else {
            throw WorkoutError.parseFailed
        }
        let jsonData = String(t[start...end]).data(using: .utf8)!
        let json = try JSONDecoder().decode(FormResultJSON.self, from: jsonData)
        return FormAnalysisResult(
            exercise: json.exercise,
            overallScore: json.overallScore,
            strengths: json.strengths,
            improvements: json.improvements,
            safetyNotes: json.safetyNotes,
            tips: json.tips
        )
    }

    enum WorkoutError: LocalizedError {
        case noFrames, apiError, noResponse, parseFailed
        var errorDescription: String? {
            switch self {
            case .noFrames:    return "No video frames to analyze."
            case .apiError:    return "Could not reach the AI. Check your connection."
            case .noResponse:  return "No response from AI."
            case .parseFailed: return "Could not read the analysis result."
            }
        }
    }

    private struct ClaudeMessageResponse: Decodable {
        struct Content: Decodable { let type: String; let text: String? }
        let content: [Content]
    }

    private struct FormResultJSON: Decodable {
        let exercise: String
        let overallScore: String
        let strengths: [String]
        let improvements: [String]
        let safetyNotes: [String]
        let tips: String
    }
}
