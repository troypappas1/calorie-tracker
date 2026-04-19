import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FoodAnalysisViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    imageSection
                    controlsSection
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

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snap your meal.")
                .font(.largeTitle.bold())

            Text("Estimate calories and protein from a food photo in a few seconds.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            Text("Use the camera or pick one from your library.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.headline)

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

            Button {
                Task {
                    await viewModel.analyzeSelectedImage()
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
            .disabled(viewModel.selectedImage == nil || viewModel.isAnalyzing)

            Text("Provider: \(viewModel.configuration.provider.displayName)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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

                NutritionResultCard(result: result)
            } else {
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
