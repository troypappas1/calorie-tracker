import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FoodAnalysisViewModel()

    var body: some View {
        TabView {
            FoodScanView(viewModel: viewModel)
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            MyDayView(mealLog: viewModel.mealLog)
                .tabItem { Label("My Day", systemImage: "sun.max") }
        }
    }
}

private struct FoodScanView: View {
    @ObservedObject var viewModel: FoodAnalysisViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modePickerSection
                    if viewModel.inputMode == .photo {
                        imageSection
                    } else {
                        textSection
                    }
                    analyzeButton
                    resultSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Food Scan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings") {
                        viewModel.isShowingSettings = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingCamera) {
                CameraPicker { image in
                    viewModel.setCapturedImage(image)
                }
            }
            .task(id: viewModel.selectedPhotoItem) {
                await viewModel.loadSelectedPhoto()
            }
        }
    }

    private var modePickerSection: some View {
        Picker("Input Mode", selection: $viewModel.inputMode) {
            Label("Photo", systemImage: "camera").tag(FoodAnalysisViewModel.InputMode.photo)
            Label("Describe", systemImage: "text.bubble").tag(FoodAnalysisViewModel.InputMode.text)
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.inputMode) { _, _ in
            viewModel.estimate = nil
            viewModel.errorMessage = nil
        }
    }

    private var imageSection: some View {
        VStack(spacing: 16) {
            Group {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemFill))
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 42))
                                .foregroundStyle(.secondary)
                            Text("Add a food photo")
                                .font(.headline)
                            Text("Use the camera or pick from your library.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            HStack(spacing: 12) {
                Button {
                    viewModel.isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(
                    selection: $viewModel.selectedPhotoItem,
                    matching: .images,
                    preferredItemEncoding: .automatic
                ) {
                    Label("Library", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Describe your meal")
                .font(.headline)
            TextEditor(text: $viewModel.descriptionText)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        }
    }

    private var analyzeButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if viewModel.inputMode == .photo {
                        await viewModel.analyzeSelectedImage()
                    } else {
                        await viewModel.analyzeDescription()
                    }
                }
            } label: {
                if viewModel.isAnalyzing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Analyze Nutrition")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAnalyzeDisabled)

            Text("Provider: \(viewModel.configuration.provider.displayName)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var isAnalyzeDisabled: Bool {
        if viewModel.isAnalyzing { return true }
        if viewModel.inputMode == .photo { return viewModel.selectedImage == nil }
        return viewModel.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            if let result = viewModel.estimate {
                Text("Estimate")
                    .font(.headline)

                NutritionResultCard(result: result) {
                    viewModel.logCurrentEstimate()
                }
            } else if viewModel.errorMessage == nil {
                Text("No nutrition estimate yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
