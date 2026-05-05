import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FoodAnalysisViewModel()
    @EnvironmentObject private var auth: GoogleAuthService

    var body: some View {
        TabView {
            AnalyzeTab(viewModel: viewModel)
                .tabItem { Label("Analyze", systemImage: "camera.viewfinder") }

            MyDayTab(mealLog: viewModel.mealLog)
                .tabItem { Label("My Day", systemImage: "sun.max") }

            WorkoutTab()
                .tabItem { Label("Workout", systemImage: "figure.run") }

            ProfileTab(auth: auth)
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .tint(Color.ctAccent)
        .sheet(isPresented: $viewModel.isShowingCamera) {
            CameraPicker { image in viewModel.setCapturedImage(image) }
        }
        .task(id: viewModel.selectedPhotoItem) {
            await viewModel.loadSelectedPhoto()
        }
    }
}

// MARK: - Analyze Tab

struct AnalyzeTab: View {
    @ObservedObject var viewModel: FoodAnalysisViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    modeToggle
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    if viewModel.inputMode == .photo {
                        photoContent
                    } else {
                        describeContent
                    }

                    if let result = viewModel.estimate {
                        NutritionResultCard(result: result) {
                            viewModel.logCurrentEstimate()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analyze")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("Photo", icon: "camera.fill", mode: .photo)
            modeButton("Describe", icon: "text.bubble.fill", mode: .text)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func modeButton(_ label: String, icon: String, mode: FoodAnalysisViewModel.InputMode) -> some View {
        let selected = viewModel.inputMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.inputMode = mode
                viewModel.estimate = nil
                viewModel.errorMessage = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(selected ? .white : Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.ctAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(3)
    }

    // MARK: Photo content

    private var photoContent: some View {
        VStack(spacing: 0) {
            // Hero image / upload zone
            ZStack {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 52, weight: .thin))
                                    .foregroundStyle(Color.ctAccent)
                                Text("Add a Food Photo")
                                    .font(.title3.bold())
                                Text("Tap Camera or Library to get started")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }

            // Buttons row
            HStack(spacing: 12) {
                Button {
                    viewModel.isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ctAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    Label("Library", systemImage: "photo.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(Color(.label))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGroupedBackground))

            analyzeAndClearButtons
        }
    }

    // MARK: Describe content

    private var describeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe your meal")
                .font(.headline)
                .padding(.horizontal, 20)

            ZStack(alignment: .topLeading) {
                if viewModel.descriptionText.isEmpty {
                    Text("e.g. \"Grilled chicken with rice and broccoli, medium portion\"")
                        .foregroundStyle(Color(.placeholderText))
                        .font(.body)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.descriptionText)
                    .font(.body)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            analyzeAndClearButtons
        }
    }

    // MARK: Shared buttons

    private var analyzeAndClearButtons: some View {
        VStack(spacing: 10) {
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
                        Text("Analyze Nutrition").fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isAnalyzeDisabled ? Color(.systemFill) : Color.ctAccent)
                .foregroundStyle(isAnalyzeDisabled ? Color(.secondaryLabel) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isAnalyzeDisabled)

            if viewModel.selectedImage != nil || !viewModel.descriptionText.isEmpty {
                Button("Clear") { viewModel.clearInput() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var isAnalyzeDisabled: Bool {
        if viewModel.isAnalyzing { return true }
        if viewModel.inputMode == .photo { return viewModel.selectedImage == nil }
        return viewModel.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - My Day Tab

struct MyDayTab: View {
    @ObservedObject var mealLog: MealLog
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if mealLog.todayEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        MyDayEmbeddedView(mealLog: mealLog)
                            .padding(16)
                            .padding(.bottom, 32)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("My Day")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !mealLog.todayEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { showClearConfirm = true }
                            .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog("Clear all meals for today?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Day", role: .destructive) { mealLog.clearToday() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Color.ctAccent)
            Text("Nothing logged yet")
                .font(.title3.bold())
            Text("Analyze a meal and tap\n\"Add to My Day\" to track it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Workout Tab

struct WorkoutTab: View {
    var body: some View {
        NavigationStack {
            WorkoutComingSoonView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Workout")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Profile Tab

struct ProfileTab: View {
    @ObservedObject var auth: GoogleAuthService
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.ctAccent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(auth.currentUser?.profile?.name ?? "User")
                                .font(.headline)
                            Text(auth.currentUser?.profile?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // About
                Section("About") {
                    Label("Powered by Claude AI", systemImage: "brain")
                    Label("Photos analyzed privately", systemImage: "lock.shield")
                    Label("Data stored on your device", systemImage: "iphone")
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog("Sign out of your account?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
        }
    }
}

#Preview { ContentView() }
