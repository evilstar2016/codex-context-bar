import Foundation

/// Skill Doctor's approximate four-unit counter, using UTF-8 bytes so CJK text is not treated as quarter-token characters.
public enum TokenEstimate {
    public static func count(_ text: String) -> Int {
        (text.utf8.count + 3) / 4
    }
}

/// Reference document prices (2026-09-07), not live-verified; USD per million tokens.
public struct InputPrice: Sendable {
    public static let checkedAt = "2026-09-07"

    public let model: String
    public let ordinary: Double
    public let cached: Double
    public let cacheWrite: Double?
    public let output: Double
    public let maximumInputTokens: Int

    public static func forModel(_ model: String?) -> InputPrice? {
        guard let rawModel = model else { return nil }
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch model {
        case "gpt-6-astra": return .init(model: model, ordinary: 20, cached: 2, cacheWrite: 25, output: 75, maximumInputTokens: 200_000)
        case "gpt-5.6-sol": return .init(model: model, ordinary: 8, cached: 0.8, cacheWrite: 10, output: 30, maximumInputTokens: 200_000)
        case "gpt-5.6-terra": return .init(model: model, ordinary: 4, cached: 0.4, cacheWrite: 5, output: 18, maximumInputTokens: 200_000)
        case "gpt-5.6-luna": return .init(model: model, ordinary: 0.4, cached: 0.04, cacheWrite: 0.5, output: 1.8, maximumInputTokens: 200_000)
        case "gpt-5.3-codex": return .init(model: model, ordinary: 1.75, cached: 0.175, cacheWrite: nil, output: 14, maximumInputTokens: 200_000)
        default: return nil
        }
    }

    public static var maximum: InputPrice { forModel("gpt-6-astra")! }

    public func cost(_ usage: TokenUsage) -> Double? {
        guard usage.validPartitions, usage.input <= maximumInputTokens else { return nil }
        // Match the reference calculator's missing cache-write price behavior.
        if usage.input > 0 && cacheWrite == nil { return nil }
        return (Double(usage.input - usage.cached - usage.cacheWrite) * ordinary
            + Double(usage.cached) * cached + Double(usage.cacheWrite) * (cacheWrite ?? 0)
            + Double(usage.output) * output) / 1_000_000
    }

    public func savings(tokens: Int, usage: TokenUsage) -> ClosedRange<Double>? {
        guard usage.validPartitions, tokens >= 0, tokens <= usage.input,
              usage.input <= maximumInputTokens, usage.cacheWrite == 0 else { return nil }
        let minCached = max(0, tokens - (usage.input - usage.cached))
        let maxCached = min(tokens, usage.cached)
        let a = ordinaryCost(tokens: tokens - minCached) + cachedCost(tokens: minCached)
        let b = ordinaryCost(tokens: tokens - maxCached) + cachedCost(tokens: maxCached)
        return min(a, b)...max(a, b)
    }

    public func ordinaryCost(tokens: Int) -> Double {
        Double(tokens) * ordinary / 1_000_000
    }

    public func cachedCost(tokens: Int) -> Double {
        Double(tokens) * cached / 1_000_000
    }
}
