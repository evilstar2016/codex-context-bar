import Foundation

public struct SavingsSnapshot: Sendable {
    public let tokens: Int
    public let initialTokens: Int
    public let ordinaryUSD: Double?
    public let cachedUSD: Double?
    public let sessionCount: Int
    public let pricedSessionCount: Int
    public let unpricedSessionCount: Int
    public let projectCount: Int
    public let allThreeCount: Int
    public let incompleteCount: Int
    public let byTarget: [ControlTarget: Int]
    public let byTargetUSD: [ControlTarget: Double]
}

public struct SavingsSummary: Sendable {
    public let current7: SavingsSnapshot
    public let current30: SavingsSnapshot
    public let all7: SavingsSnapshot
    public let all30: SavingsSnapshot

    public init(sessions: [SessionHeader], project: URL, now: Date = Date()) {
        let path = canonicalPath(project)
        current7 = Self.snapshot(sessions, project: path, days: 7, now: now)
        current30 = Self.snapshot(sessions, project: path, days: 30, now: now)
        all7 = Self.snapshot(sessions, project: nil, days: 7, now: now)
        all30 = Self.snapshot(sessions, project: nil, days: 30, now: now)
    }

    private static func snapshot(_ sessions: [SessionHeader], project: String?, days: Int, now: Date) -> SavingsSnapshot {
        let cutoff = now.addingTimeInterval(TimeInterval(-days * 86_400))
        let matching = sessions.filter { $0.date >= cutoff && $0.date <= now && (project == nil || $0.project == project) }
        let complete = matching.filter(\.complete)
        var byTarget = Dictionary(uniqueKeysWithValues: ControlTarget.allCases.map { ($0, 0) })
        var byTargetUSD = Dictionary(uniqueKeysWithValues: ControlTarget.allCases.map { ($0, 0.0) })
        var ordinaryUSD = 0.0
        var cachedUSD = 0.0
        var pricedCount = 0
        for session in complete {
            let controlledTokens = ControlTarget.allCases.reduce(0) { sum, target in
                let tokens = session.blocks.filter { target.kinds.contains($0.kind) }.reduce(0) { $0 + $1.tokens }
                byTarget[target, default: 0] += tokens
                return sum + tokens
            }
            if controlledTokens == 0 {
                pricedCount += 1
            } else if let price = InputPrice.forModel(session.model), session.tokens <= price.maximumInputTokens {
                pricedCount += 1
                ordinaryUSD += price.ordinaryCost(tokens: controlledTokens)
                cachedUSD += price.cachedCost(tokens: controlledTokens)
                for target in ControlTarget.allCases {
                    let tokens = session.blocks.filter { target.kinds.contains($0.kind) }.reduce(0) { $0 + $1.tokens }
                    byTargetUSD[target, default: 0] += price.ordinaryCost(tokens: tokens)
                }
            }
        }
        return SavingsSnapshot(
            tokens: byTarget.values.reduce(0, +),
            initialTokens: complete.reduce(0) { $0 + $1.tokens },
            ordinaryUSD: pricedCount > 0 ? ordinaryUSD : nil,
            cachedUSD: pricedCount > 0 ? cachedUSD : nil,
            sessionCount: complete.count,
            pricedSessionCount: pricedCount,
            unpricedSessionCount: complete.count - pricedCount,
            projectCount: Set(complete.map(\.project)).count,
            allThreeCount: complete.filter { session in ControlTarget.allCases.allSatisfy(session.contains) }.count,
            incompleteCount: matching.count - complete.count,
            byTarget: byTarget,
            byTargetUSD: byTargetUSD
        )
    }
}
