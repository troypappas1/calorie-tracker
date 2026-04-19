import Foundation

struct AppConfiguration {
    enum Provider: String, CaseIterable, Identifiable {
        case mock
        case openAI

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .mock:
                return "Mock"
            case .openAI:
                return "OpenAI"
            }
        }
    }

    var provider: Provider
    var openAIKey: String

    static let providerKey = "app.provider"
    static let openAIKeyKey = "app.openai.key"

    static func load() -> AppConfiguration {
        let defaults = UserDefaults.standard
        let provider = Provider(rawValue: defaults.string(forKey: providerKey) ?? Provider.mock.rawValue) ?? .mock
        let openAIKey = defaults.string(forKey: openAIKeyKey) ?? ""
        return AppConfiguration(provider: provider, openAIKey: openAIKey)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        defaults.set(openAIKey, forKey: Self.openAIKeyKey)
    }
}
