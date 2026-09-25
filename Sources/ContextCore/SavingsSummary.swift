import Foundation

public struct SavingsSnapshot: Sendable {
    public let characters: Int
    public let initialCharacters: Int
    public let sessionCount: Int
    public let projectCount: Int
    public let allThreeCount: Int
    public let incompleteCount: Int
    public let byTarget: [ControlTarget: Int]
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
        for session in complete {
            for target in ControlTarget.allCases {
                byTarget[target, default: 0] += session.blocks
                    .filter { target.kinds.contains($0.kind) }
                    .reduce(0) { $0 + $1.characters }
            }
        }
        return SavingsSnapshot(
            characters: byTarget.values.reduce(0, +),
            initialCharacters: complete.reduce(0) { $0 + $1.characters },
            sessionCount: complete.count,
            projectCount: Set(complete.map(\.project)).count,
            allThreeCount: complete.filter { session in ControlTarget.allCases.allSatisfy(session.contains) }.count,
            incompleteCount: matching.count - complete.count,
            byTarget: byTarget
        )
    }
}
