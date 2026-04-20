import Foundation

struct AppConfiguration {
    enum Provider: String, CaseIterable, Identifiable {
        case mock
        case anthropic
        case openAI

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .mock: return "Mock"
            case .anthropic: return "Claude (Anthropic)"
            case .openAI: return "OpenAI"
            }
        }
    }

    var provider: Provider
    var openAIKey: String
    var anthropicKey: String

    static let providerKey = "app.provider"
    static let openAIKeyKey = "app.openai.key"
    static let anthropicKeyKey = "app.anthropic.key"

    static func load() -> AppConfiguration {
        let defaults = UserDefaults.standard
        let provider = Provider(rawValue: defaults.string(forKey: providerKey) ?? Provider.mock.rawValue) ?? .mock
        let openAIKey = defaults.string(forKey: openAIKeyKey) ?? ""
        let anthropicKey = defaults.string(forKey: anthropicKeyKey) ?? ""
        return AppConfiguration(provider: provider, openAIKey: openAIKey, anthropicKey: anthropicKey)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        defaults.set(openAIKey, forKey: Self.openAIKeyKey)
        defaults.set(anthropicKey, forKey: Self.anthropicKeyKey)
    }
}
