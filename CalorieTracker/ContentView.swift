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
            ZStack {
                WarmBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        inputCard
                        if viewModel.estimate != nil || viewModel.errorMessage != nil {
                            resultCard
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Food Scan")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Input card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Mode", selection: $viewModel.inputMode) {
                Label("Photo", systemImage: "camera").tag(FoodAnalysisViewModel.InputMode.photo)
                Label("Describe", systemImage: "text.bubble").tag(FoodAnalysisViewModel.InputMode.text)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.inputMode) { _, _ in
                viewModel.estimate = nil
                viewModel.errorMessage = nil
            }

            if viewModel.inputMode == .photo {
                photoSection
            } else {
                notesSection
            }

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
                Button("Clear") { viewModel.clearInput() }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.ctSerif(13)).foregroundStyle(.red)
            }
        }
        .padding(20)
        .ctPanel()
    }

    // MARK: Photo section

    private var photoSection: some View {
        VStack(spacing: 12) {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                uploadZone
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                PhotosPicker(
                    selection: $viewModel.selectedPhotoItem,
                    matching: .images
                ) {
                    Label("Library", systemImage: "photo")
                        .font(.ctSerif(16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ctMuted.opacity(0.12))
                        .clipShape(Capsule())
                }
                .foregroundStyle(Color.ctText)
            }
        }
    }

    private var uploadZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(Color.ctAccent)
            Text("Choose a food photo")
                .font(.ctSerifBold(16))
                .foregroundStyle(Color.ctText)
            Text("Tap Camera or Library below")
                .font(.ctSerif(13))
                .foregroundStyle(Color.ctMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color(red: 1, green: 0.98, blue: 0.945))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(style: StrokeStyle(lineWidth: 2, dash: [6])).foregroundStyle(Color.ctAccentDark.opacity(0.3)))
    }

    // MARK: Notes section

    private var notesSection: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.descriptionText.isEmpty {
                Text("e.g. \u{201C}A bowl of oatmeal with blueberries and honey\u{201D}")
                    .font(.ctSerif(15))
                    .foregroundStyle(Color.ctMuted)
                    .padding(.top, 20)
                    .padding(.leading, 18)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $viewModel.descriptionText)
                .font(.ctSerif(15))
                .foregroundStyle(Color.ctText)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(red: 1, green: 0.98, blue: 0.945))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(style: StrokeStyle(lineWidth: 2, dash: [6])).foregroundStyle(Color.ctAccentDark.opacity(0.3)))
        }
    }

    // MARK: Result card

    @ViewBuilder
    private var resultCard: some View {
        if let result = viewModel.estimate {
            NutritionResultCard(result: result) {
                viewModel.logCurrentEstimate()
            }
        } else if let error = viewModel.errorMessage {
            Text(error).font(.ctSerif(14)).foregroundStyle(.red).padding(20).ctPanel()
        }
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

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                Group {
                    if mealLog.todayEntries.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            MyDayEmbeddedView(mealLog: mealLog)
                                .padding(16)
                                .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("My Day")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundStyle(Color.ctAccent)
            Text("No meals logged today")
                .font(.ctSerifBold(20))
                .foregroundStyle(Color.ctText)
            Text("Analyze a meal and tap\n\"Add to My Day\" to log it here.")
                .font(.ctSerif(15))
                .foregroundStyle(Color.ctMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Workout Tab

struct WorkoutTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                WorkoutComingSoonView()
                    .padding(20)
            }
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
            ZStack {
                WarmBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        profileCard
                        aboutCard
                        signOutButton
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog("Sign out of your account?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.ctAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text(auth.currentUser?.profile?.name ?? "User")
                    .font(.ctSerifBold(18))
                    .foregroundStyle(Color.ctText)
                Text(auth.currentUser?.profile?.email ?? "")
                    .font(.ctSerif(14))
                    .foregroundStyle(Color.ctMuted)
            }
            Spacer()
        }
        .padding(20)
        .ctPanel()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.ctSerifBold(16))
                .foregroundStyle(Color.ctText)
            Text("Calorie Tracker uses Claude AI to analyze your meals from photos or descriptions and give you a full nutrition breakdown.")
                .font(.ctSerif(14))
                .foregroundStyle(Color.ctMuted)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctPanel()
    }

    private var signOutButton: some View {
        Button("Sign Out") { showSignOutConfirm = true }
            .font(.ctSerif(16, weight: .bold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .clipShape(Capsule())
    }
}

#Preview { ContentView() }
