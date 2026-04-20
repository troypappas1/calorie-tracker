import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FoodAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var provider: AppConfiguration.Provider
    @State private var openAIKey: String
    @State private var anthropicKey: String

    init(viewModel: FoodAnalysisViewModel) {
        self.viewModel = viewModel
        _provider = State(initialValue: viewModel.configuration.provider)
        _openAIKey = State(initialValue: viewModel.configuration.openAIKey)
        _anthropicKey = State(initialValue: viewModel.configuration.anthropicKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Analyzer") {
                    Picker("Provider", selection: $provider) {
                        ForEach(AppConfiguration.Provider.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("Claude (Anthropic)") {
                    SecureField("API key", text: $anthropicKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Get a key at console.anthropic.com. Select \"Claude\" as the provider.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("OpenAI") {
                    SecureField("API key", text: $openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Get a key at platform.openai.com. Select \"OpenAI\" as the provider.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.saveConfiguration(
                            provider: provider,
                            openAIKey: openAIKey,
                            anthropicKey: anthropicKey
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
