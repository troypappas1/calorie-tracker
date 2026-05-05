import Foundation

// MARK: - Workout goal

enum WorkoutGoal: String, CaseIterable, Identifiable {
    case loseFat       = "lose_fat"
    case gainMuscle    = "gain_muscle"
    case hypertrophy   = "hypertrophy"
    case getDefinedLean = "get_defined"
    case generalFitness = "general_fitness"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loseFat:        return "Lose Fat"
        case .gainMuscle:     return "Gain Muscle & Strength"
        case .hypertrophy:    return "Hypertrophy (Maximize Size)"
        case .getDefinedLean: return "Get Lean & Defined"
        case .generalFitness: return "General Fitness"
        }
    }

    var icon: String {
        switch self {
        case .loseFat:        return "flame.fill"
        case .gainMuscle:     return "dumbbell.fill"
        case .hypertrophy:    return "chart.bar.fill"
        case .getDefinedLean: return "figure.cooldown"
        case .generalFitness: return "heart.fill"
        }
    }
}

enum FitnessLevel: String, CaseIterable, Identifiable {
    case beginner     = "beginner"
    case intermediate = "intermediate"
    case advanced     = "advanced"

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum WorkoutDaysPerWeek: Int, CaseIterable, Identifiable {
    case two = 2, three = 3, four = 4, five = 5, six = 6
    var id: Int { rawValue }
    var displayName: String { "\(rawValue) days/week" }
}

// MARK: - Workout plan profile

struct WorkoutProfile {
    var goal: WorkoutGoal = .loseFat
    var fitnessLevel: FitnessLevel = .beginner
    var currentWeightLbs: String = ""
    var targetWeightLbs: String = ""
    var timelineWeeks: String = ""
    var daysPerWeek: WorkoutDaysPerWeek = .three
    var equipment: String = "gym"
    var notes: String = ""
}

// MARK: - Generated plan

struct WorkoutPlan: Identifiable {
    let id = UUID()
    let goal: WorkoutGoal
    let content: String
    let createdAt: Date
}

// MARK: - Form analysis result

struct FormAnalysisResult {
    let exercise: String
    let overallScore: String
    let strengths: [String]
    let improvements: [String]
    let safetyNotes: [String]
    let tips: String
}
