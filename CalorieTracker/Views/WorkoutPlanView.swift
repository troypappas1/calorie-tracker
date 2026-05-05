import SwiftUI

struct WorkoutPlanView: View {
    @State private var profile = WorkoutProfile()
    @State private var generatedPlan: String? = nil
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var showPlan = false

    private let service = WorkoutService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    goalSection
                    levelAndDaysSection
                    weightSection
                    equipmentSection
                    notesSection
                    generateButton
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Plan")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPlan) {
                if let plan = generatedPlan {
                    WorkoutPlanResultView(plan: plan, goal: profile.goal)
                }
            }
        }
    }

    // MARK: - Goal section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Your Goal")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WorkoutGoal.allCases) { goal in
                    GoalCard(goal: goal, isSelected: profile.goal == goal) {
                        profile.goal = goal
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Level and days

    private var levelAndDaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Experience Level")
            HStack(spacing: 8) {
                ForEach(FitnessLevel.allCases) { level in
                    LevelButton(label: level.displayName, isSelected: profile.fitnessLevel == level) {
                        profile.fitnessLevel = level
                    }
                }
            }

            sectionHeader("Days Per Week")
            HStack(spacing: 8) {
                ForEach(WorkoutDaysPerWeek.allCases) { days in
                    LevelButton(label: "\(days.rawValue)", isSelected: profile.daysPerWeek == days) {
                        profile.daysPerWeek = days
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Weight

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Weight (optional)")
            HStack(spacing: 12) {
                WorkoutField(label: "Current (lbs)", text: $profile.currentWeightLbs, keyboardType: .decimalPad)
                WorkoutField(label: "Target (lbs)", text: $profile.targetWeightLbs, keyboardType: .decimalPad)
                WorkoutField(label: "Weeks", text: $profile.timelineWeeks, keyboardType: .numberPad)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Equipment

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Equipment")
            HStack(spacing: 8) {
                ForEach(["Gym", "Home", "Bands", "None"], id: \.self) { eq in
                    LevelButton(label: eq, isSelected: profile.equipment.lowercased() == eq.lowercased()) {
                        profile.equipment = eq.lowercased()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Notes (optional)")
            ZStack(alignment: .topLeading) {
                if profile.notes.isEmpty {
                    Text("Any injuries, preferences, or specific requests...")
                        .foregroundStyle(Color(.placeholderText))
                        .font(.subheadline)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $profile.notes)
                    .font(.subheadline)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Generate button

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            Group {
                if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Generating Plan...").fontWeight(.bold)
                    }
                } else {
                    Text("Generate My Plan").fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isGenerating ? Color(.systemFill) : Color.ctAccent)
            .foregroundStyle(isGenerating ? Color(.secondaryLabel) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isGenerating)
        .padding(.horizontal, 20)
    }

    // MARK: - Generate action

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        do {
            let plan = try await service.generatePlan(profile: profile)
            generatedPlan = plan
            showPlan = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: WorkoutGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: goal.icon)
                    .font(.system(size: 16))
                    .frame(width: 22)
                Text(goal.displayName)
                    .font(.caption.bold())
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.ctAccent : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.ctAccent : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Level Button

private struct LevelButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.ctAccent : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : Color(.label))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Workout Field

private struct WorkoutField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("—", text: $text)
                .keyboardType(keyboardType)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Plan Result View

struct WorkoutPlanResultView: View {
    let plan: String
    let goal: WorkoutGoal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(plan)
                    .font(.system(.body, design: .monospaced))
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(goal.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: plan) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
