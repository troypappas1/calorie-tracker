import SwiftUI
import PhotosUI
import AVFoundation

struct FormAnalysisView: View {
    @State private var selectedVideo: PhotosPickerItem? = nil
    @State private var exerciseName: String = ""
    @State private var isAnalyzing = false
    @State private var result: FormAnalysisResult? = nil
    @State private var errorMessage: String? = nil
    @State private var thumbnailImage: UIImage? = nil
    @State private var videoURL: URL? = nil

    private let service = WorkoutService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    videoPickerSection
                    exerciseNameSection
                    analyzeButton
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }
                    if let result = result {
                        FormResultCard(result: result)
                            .padding(.horizontal, 20)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form Analysis")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: selectedVideo) { _, _ in
            Task { await loadVideo() }
        }
    }

    // MARK: - Video picker

    private var videoPickerSection: some View {
        VStack(spacing: 0) {
            ZStack {
                if let thumb = thumbnailImage {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "video.fill")
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(12)
                        }
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 52, weight: .thin))
                                    .foregroundStyle(Color.ctAccent)
                                Text("Add Workout Video")
                                    .font(.title3.bold())
                                Text("Select a short clip (5–15 sec)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }

            PhotosPicker(selection: $selectedVideo, matching: .videos) {
                Label("Choose Video", systemImage: "video.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.ctAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Exercise name

    private var exerciseNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercise Name (optional)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            TextField("e.g. Squat, Deadlift, Bench Press", text: $exerciseName)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Analyze button

    private var analyzeButton: some View {
        Button {
            Task { await analyze() }
        } label: {
            Group {
                if isAnalyzing {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Analyzing Form...").fontWeight(.bold)
                    }
                } else {
                    Text("Analyze My Form").fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(analyzeDisabled ? Color(.systemFill) : Color.ctAccent)
            .foregroundStyle(analyzeDisabled ? Color(.secondaryLabel) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(analyzeDisabled)
        .padding(.horizontal, 20)
    }

    private var analyzeDisabled: Bool {
        isAnalyzing || videoURL == nil
    }

    // MARK: - Actions

    private func loadVideo() async {
        guard let item = selectedVideo else { return }
        thumbnailImage = nil
        videoURL = nil
        result = nil
        errorMessage = nil

        do {
            guard let url = try await item.loadTransferable(type: VideoFileTransferable.self)?.url else { return }
            videoURL = url
            thumbnailImage = await extractThumbnail(from: url)
        } catch {
            errorMessage = "Could not load video: \(error.localizedDescription)"
        }
    }

    private func analyze() async {
        guard let url = videoURL else { return }
        isAnalyzing = true
        errorMessage = nil
        result = nil

        do {
            let frames = await extractFrames(from: url, count: 4)
            guard !frames.isEmpty else {
                errorMessage = "Could not extract frames from video."
                isAnalyzing = false
                return
            }
            result = try await service.analyzeForm(frames: frames, exerciseName: exerciseName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isAnalyzing = false
    }

    private func extractThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        if let cgImage = try? await gen.image(at: time).image {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    private func extractFrames(from url: URL, count: Int) async -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 720, height: 720)

        let duration: Double
        if let d = try? await asset.load(.duration) {
            duration = d.seconds
        } else {
            duration = 5.0
        }

        var frames: [UIImage] = []
        for i in 0..<count {
            let t = duration * Double(i) / Double(count)
            let time = CMTime(seconds: t, preferredTimescale: 600)
            if let cgImage = try? await gen.image(at: time).image {
                frames.append(UIImage(cgImage: cgImage))
            }
        }
        return frames
    }
}

// MARK: - Video Transferable

struct VideoFileTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFileTransferable(url: copy)
        }
    }
}

// MARK: - Form Result Card

struct FormResultCard: View {
    let result: FormAnalysisResult

    private var scoreColor: Color {
        switch result.overallScore.lowercased() {
        case "excellent": return .green
        case "good":      return Color.ctAccent
        default:          return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.exercise)
                        .font(.headline)
                    Text("Form Analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(result.overallScore)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(scoreColor)
                    .clipShape(Capsule())
            }

            Divider()

            // Strengths
            if !result.strengths.isEmpty {
                ResultSection(title: "Strengths", icon: "checkmark.circle.fill", color: .green, items: result.strengths)
            }

            // Improvements
            if !result.improvements.isEmpty {
                ResultSection(title: "Improvements", icon: "arrow.up.circle.fill", color: Color.ctAccent, items: result.improvements)
            }

            // Safety
            if !result.safetyNotes.isEmpty {
                ResultSection(title: "Safety Notes", icon: "exclamationmark.triangle.fill", color: .red, items: result.safetyNotes)
            }

            // Key tip
            if !result.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Key Tip", systemImage: "lightbulb.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                    Text(result.tips)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct ResultSection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
