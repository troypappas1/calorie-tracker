import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FoodAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var provider: AppConfiguration.Provider
    @State private var apiKey: String

    init(viewModel: FoodAnalysisViewModel) {
        self.viewModel = viewModel
        _provider = State(initialValue: viewModel.configuration.provider)
        _apiKey = State(initialValue: viewModel.configuration.openAIKey)
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

                Section("OpenAI") {
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Use the OpenAI provider when you want a real image-based estimate instead of the built-in mock result.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.saveConfiguration(provider: provider, apiKey: apiKey)
                        dismiss()
                    }
                }
            }
        }
    }
}
