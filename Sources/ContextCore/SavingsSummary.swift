import Foundation

public enum SavingsPricingMode: Sendable {
    case maximum, actual
}

public struct SavingsSnapshot: Sendable {
    public let tokens: Int
    public let initialTokens: Int
    public let savingsUSD: ClosedRange<Double>?
    public let cost: Double?
    public let actualCost: Double?
    public let responseCount: Int
    public let costCoverage: Int
    public let actualCostCoverage: Int
    public let savingsCoverage: Int
    public let sessionCount: Int
    public let pricedSessionCount: Int
    public let unpricedSessionCount: Int
    public let projectCount: Int
    public let allThreeCount: Int
    public let incompleteCount: Int
    public let byTarget: [ControlTarget: Int]
    public let byTargetUSD: [ControlTarget: ClosedRange<Double>]
}

public struct SavingsSummary: Sendable {
    public let current7: SavingsSnapshot
    public let current30: SavingsSnapshot
    public let all7: SavingsSnapshot
    public let all30: SavingsSnapshot

    public init(sessions: [SessionHeader], project: URL, now: Date = Date(), pricingMode: SavingsPricingMode = .maximum) {
        let path = canonicalPath(project)
        current7 = Self.snapshot(sessions, project: path, days: 7, now: now, pricingMode: pricingMode)
        current30 = Self.snapshot(sessions, project: path, days: 30, now: now, pricingMode: pricingMode)
        all7 = Self.snapshot(sessions, project: nil, days: 7, now: now, pricingMode: pricingMode)
        all30 = Self.snapshot(sessions, project: nil, days: 30, now: now, pricingMode: pricingMode)
    }

    private static func snapshot(_ sessions: [SessionHeader], project: String?, days: Int, now: Date, pricingMode: SavingsPricingMode) -> SavingsSnapshot {
        let cutoff = now.addingTimeInterval(TimeInterval(-days * 86_400))
        var ids = Set<String>()
        let matching = sessions.sorted { $0.lastActivity > $1.lastActivity }.filter {
            ids.insert($0.sessionID ?? $0.id).inserted && (project == nil || $0.project == project)
                && (($0.date >= cutoff && $0.date <= now) || $0.responses.contains { $0.date >= cutoff && $0.date <= now })
        }
        var byTarget: [ControlTarget: Int] = [:]
        var byTargetUSD: [ControlTarget: ClosedRange<Double>] = [:]
        var lower = 0.0, upper = 0.0, cost = 0.0, actualCost = 0.0
        var responseCount = 0, costCoverage = 0, actualCoverage = 0, savingsCoverage = 0, pricedSessions = 0
        for session in matching {
            var sessionPriced = false
            for response in session.responses where response.date >= cutoff && response.date <= now {
                responseCount += 1
                guard let usage = response.usage, usage.validPartitions else { continue }
                if let amount = InputPrice.maximum.cost(usage) { cost += amount; costCoverage += 1 }
                let actualPrice = InputPrice.forModel(response.model)
                if let amount = actualPrice?.cost(usage) { actualCost += amount; actualCoverage += 1 }
                let price = pricingMode == .maximum ? InputPrice.maximum : actualPrice
                let targets = response.targets.filter { $0.value <= usage.input }
                var responsePriced = false
                for (target, tokens) in targets {
                    byTarget[target, default: 0] += tokens
                    if let range = price?.savings(tokens: tokens, usage: usage) {
                        let old = byTargetUSD[target] ?? 0...0
                        byTargetUSD[target] = (old.lowerBound + range.lowerBound)...(old.upperBound + range.upperBound)
                        lower += range.lowerBound; upper += range.upperBound
                        responsePriced = true
                    }
                }
                if responsePriced { savingsCoverage += 1; sessionPriced = true }
            }
            if sessionPriced { pricedSessions += 1 }
        }
        return SavingsSnapshot(
            tokens: byTarget.values.reduce(0, +),
            initialTokens: matching.filter(\.complete).reduce(0) { $0 + $1.tokens },
            savingsUSD: savingsCoverage > 0 ? lower...upper : nil,
            cost: costCoverage > 0 ? cost : nil,
            actualCost: actualCoverage > 0 ? actualCost : nil,
            responseCount: responseCount, costCoverage: costCoverage, actualCostCoverage: actualCoverage,
            savingsCoverage: savingsCoverage,
            sessionCount: matching.count,
            pricedSessionCount: pricedSessions,
            unpricedSessionCount: matching.count - pricedSessions,
            projectCount: Set(matching.map(\.project)).count,
            allThreeCount: matching.filter { $0.complete && ControlTarget.allCases.allSatisfy($0.contains) }.count,
            incompleteCount: matching.filter { !$0.complete }.count,
            byTarget: byTarget, byTargetUSD: byTargetUSD
        )
    }
}
