import Foundation

/// Skill Doctor's approximate four-unit counter, using UTF-8 bytes so CJK text is not treated as quarter-token characters.
public enum TokenEstimate {
    public static func count(_ text: String) -> Int {
        (text.utf8.count + 3) / 4
    }
}

/// Standard short-context API-equivalent input prices, in USD per million tokens.
public struct InputPrice: Sendable {
    public static let source = "https://developers.openai.com/api/docs/pricing"
    public static let checkedAt = "2026-09-25"

    public let model: String
    public let ordinary: Double
    public let cached: Double
    public let cacheWrite: Double?
    public let maximumInputTokens: Int

    public static func forModel(_ model: String?) -> InputPrice? {
        guard let model else { return nil }
        switch model {
        case "gpt-6-astra": return .init(model: model, ordinary: 10, cached: 1, cacheWrite: 12.5, maximumInputTokens: 272_000)
        case "gpt-6-sol": return .init(model: model, ordinary: 2, cached: 0.2, cacheWrite: 2.5, maximumInputTokens: 272_000)
        case "gpt-6-luna": return .init(model: model, ordinary: 0.1, cached: 0.01, cacheWrite: 0.125, maximumInputTokens: 272_000)
        case "gpt-5.6-sol": return .init(model: model, ordinary: 4, cached: 0.4, cacheWrite: 5, maximumInputTokens: 200_000)
        case "gpt-5.6-terra": return .init(model: model, ordinary: 2, cached: 0.2, cacheWrite: 2.5, maximumInputTokens: 200_000)
        case "gpt-5.6-luna": return .init(model: model, ordinary: 0.2, cached: 0.02, cacheWrite: 0.25, maximumInputTokens: 200_000)
        case "gpt-5.3-codex": return .init(model: model, ordinary: 1.75, cached: 0.175, cacheWrite: nil, maximumInputTokens: 200_000)
        default: return nil
        }
    }

    public func ordinaryCost(tokens: Int) -> Double {
        Double(tokens) * ordinary / 1_000_000
    }

    public func cachedCost(tokens: Int) -> Double {
        Double(tokens) * cached / 1_000_000
    }
}
