import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FoodAnalysisViewModel()
    @State private var selectedTab: AppTab = .analyze

    enum AppTab { case analyze, myDay, workout }

    var body: some View {
        ZStack {
            WarmBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    tabBar
                    switch selectedTab {
                    case .analyze:  analyzeContent
                    case .myDay:    MyDayEmbeddedView(mealLog: viewModel.mealLog)
                    case .workout:  WorkoutComingSoonView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .padding(.bottom, 64)
            }
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingCamera) {
            CameraPicker { image in viewModel.setCapturedImage(image) }
        }
        .task(id: viewModel.selectedPhotoItem) {
            await viewModel.loadSelectedPhoto()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Food Photo Nutrition")
                Spacer()
                Button("Settings") { viewModel.isShowingSettings = true }
                    .font(.ctSerif(14))
                    .foregroundStyle(Color.ctAccentDark)
            }
            Text("Upload a meal photo and estimate calories.")
                .font(.ctSerifBold(32))
                .foregroundStyle(Color.ctText)
                .lineSpacing(2)
            Text("Upload a food image or describe your meal, get a full nutrition breakdown, and log your meals for the day.")
                .font(.ctSerif(16))
                .foregroundStyle(Color.ctMuted)
                .lineSpacing(4)
        }
    }

    // MARK: - Custom tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton("Analyze", tab: .analyze)
            tabButton("My Day", tab: .myDay)
            tabButton("Workout", tab: .workout)
        }
        .padding(6)
        .background(Color.ctPanel.opacity(0.7))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.ctLine, lineWidth: 1))
    }

    private func tabButton(_ label: String, tab: AppTab) -> some View {
        Button(label) {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        }
        .font(.ctSerif(15, weight: .bold))
        .foregroundStyle(selectedTab == tab ? .white : Color.ctMuted)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(selectedTab == tab ? Color.ctAccent : Color.clear)
        .clipShape(Capsule())
    }

    // MARK: - Analyze tab

    private var analyzeContent: some View {
        VStack(spacing: 20) {
            uploaderPanel
            if viewModel.estimate != nil || viewModel.errorMessage != nil {
                resultPanel
            }
        }
    }

    // MARK: - Uploader panel

    private var uploaderPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a meal")
                    .font(.ctSerifBold(20))
                    .foregroundStyle(Color.ctText)
                Text("Choose a photo or describe what you ate.")
                    .font(.ctSerif(14))
                    .foregroundStyle(Color.ctMuted)
            }

            subTabBar

            if viewModel.inputMode == .photo {
                photoSection
            } else {
                notesSection
            }

            actionButtons

            Text(statusText)
                .font(.ctSerif(14))
                .foregroundStyle(Color.ctMuted)
        }
        .padding(24)
        .ctPanel()
    }

    private var statusText: String {
        if viewModel.isAnalyzing { return "Analyzing your meal…" }
        if let error = viewModel.errorMessage { return error }
        if viewModel.inputMode == .photo {
            return viewModel.selectedImage == nil
                ? "Upload a photo or describe your meal to begin."
                : "Photo ready. Analyze whenever you're ready."
        }
        return viewModel.descriptionText.isEmpty ? "Describe your meal to begin." : "Ready to analyze."
    }

    // MARK: - Sub-tabs

    private var subTabBar: some View {
        HStack(spacing: 6) {
            subTabButton("Photo", mode: .photo)
            subTabButton("Notes", mode: .text)
        }
        .padding(4)
        .background(Color(red: 1, green: 0.98, blue: 0.95).opacity(0.8))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.ctLine, lineWidth: 1))
    }

    private func subTabButton(_ label: String, mode: FoodAnalysisViewModel.InputMode) -> some View {
        Button(label) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.inputMode = mode
                viewModel.estimate = nil
                viewModel.errorMessage = nil
            }
        }
        .font(.ctSerif(14, weight: .bold))
        .foregroundStyle(viewModel.inputMode == mode ? .white : Color.ctMuted)
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(viewModel.inputMode == mode ? Color.ctAccent : Color.clear)
        .clipShape(Capsule())
    }

    // MARK: - Photo section

    private var photoSection: some View {
        VStack(spacing: 12) {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.ctLine, lineWidth: 1))
            } else {
                uploadZone
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .font(.ctSerif(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                PhotosPicker(
                    selection: $viewModel.selectedPhotoItem,
                    matching: .images,
                    preferredItemEncoding: .automatic
                ) {
                    Label("Library", systemImage: "photo")
                        .font(.ctSerif(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.ctMuted.opacity(0.12))
                        .clipShape(Capsule())
                }
                .foregroundStyle(Color.ctText)
            }
        }
    }

    private var uploadZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 36))
                .foregroundStyle(Color.ctAccentDark)
            Text("Choose a food photo")
                .font(.ctSerifBold(17))
                .foregroundStyle(Color.ctText)
            Text("JPG, PNG, or HEIC")
                .font(.ctSerif(13))
                .foregroundStyle(Color.ctMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(red: 1, green: 0.98, blue: 0.945).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(Color.ctAccentDark.opacity(0.28))
        )
    }

    // MARK: - Notes section

    private var notesSection: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.descriptionText.isEmpty {
                Text("Describe what you ate, e.g. \u{201C}A bowl of oatmeal with blueberries, honey, and almond milk\u{201D}")
                    .font(.ctSerif(15))
                    .foregroundStyle(Color.ctMuted)
                    .padding(.top, 20)
                    .padding(.leading, 18)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $viewModel.descriptionText)
                .font(.ctSerif(15))
                .foregroundStyle(Color.ctText)
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(red: 1, green: 0.98, blue: 0.945).opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(Color.ctAccentDark.opacity(0.28))
                )
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    if viewModel.inputMode == .photo {
                        await viewModel.analyzeSelectedImage()
                    } else {
                        await viewModel.analyzeDescription()
                    }
                }
            } label: {
                Group {
                    if viewModel.isAnalyzing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Analyze Nutrition")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isAnalyzeDisabled)

            if viewModel.selectedImage != nil || !viewModel.descriptionText.isEmpty {
                Button("Clear") {
                    viewModel.selectedImage = nil
                    viewModel.selectedPhotoItem = nil
                    viewModel.descriptionText = ""
                    viewModel.estimate = nil
                    viewModel.errorMessage = nil
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var isAnalyzeDisabled: Bool {
        if viewModel.isAnalyzing { return true }
        if viewModel.inputMode == .photo { return viewModel.selectedImage == nil }
        return viewModel.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Result panel

    @ViewBuilder
    private var resultPanel: some View {
        if let result = viewModel.estimate {
            NutritionResultCard(result: result) {
                viewModel.logCurrentEstimate()
            }
        } else if let error = viewModel.errorMessage {
            Text(error)
                .font(.ctSerif(15))
                .foregroundStyle(.red)
                .padding(24)
                .ctPanel()
        }
    }
}

#Preview {
    ContentView()
}
