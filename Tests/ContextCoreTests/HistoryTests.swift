import Foundation
import Testing
@testable import ContextCore

private let historyNow = Date(timeIntervalSince1970: 1_800_000_000)

private func usage(_ input: Int = 1000, cached: Int = 800, write: Int = 0, output: Int = 100) -> [String: Any] {
    ["input_tokens": input, "cached_input_tokens": cached, "cache_write_input_tokens": write,
     "output_tokens": output, "reasoning_output_tokens": 50, "total_tokens": input + output]
}

private func response(_ id: String, turn: String = "t1", values: [String: Any] = usage(),
                      date: Date = historyNow, thread: String = "main") -> [String: Any] {
    ["type": "token_usage_record", "timestamp": ISO8601DateFormatter().string(from: date),
     "payload": ["thread_id": thread, "response_id": id, "turn_id": turn, "usage": values,
                 "thread_token_usage": usage(9000), "turn_token_usage": usage(3000)]]
}

private func context(_ text: String, kind: String = "host_skills.instructions") -> [String: Any] {
    ["type": "response_item", "payload": ["role": "developer", "content": [["text": text]],
     "internal_chat_message_metadata_passthrough": ["content_item_kinds": [kind]]]]
}

private func history(_ extra: [[String: Any]], brokenAfter: Int? = nil) throws -> SessionHeader {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    defer { try? FileManager.default.removeItem(at: file) }
    let records: [[String: Any]] = [
        ["type": "session_meta", "payload": ["id": "main", "session_id": "session", "cwd": "/fixture",
            "cli_version": "test", "timestamp": ISO8601DateFormatter().string(from: historyNow.addingTimeInterval(-40 * 86_400))]],
        context(String(repeating: "a", count: 400)),
        ["type": "response_item", "payload": ["role": "user", "content": [["text": "user"]],
            "internal_chat_message_metadata_passthrough": ["content_item_kinds": ["agents_md.instructions"]]]],
        ["type": "world_state", "payload": ["full": true]],
        ["type": "turn_context", "payload": ["turn_id": "t1", "model": "gpt-6-astra"]],
    ] + extra
    var data = Data()
    for (index, var record) in records.enumerated() {
        if record["ordinal"] == nil { record["ordinal"] = index }
        if record["timestamp"] == nil { record["timestamp"] = ISO8601DateFormatter().string(from: historyNow) }
        data.append(try JSONSerialization.data(withJSONObject: record)); data.append(10)
        if brokenAfter == index { data.append(Data("bad json\n".utf8)) }
    }
    try data.write(to: file)
    var header = try #require(try HeaderParser.read(file))
    let parsed = try HistoryParser.read(file, header: header)
    header.responses = parsed.responses; header.historyIssues = parsed.issues
    return header
}

@Test func referencePricesAndCachePartitions() throws {
    let price = try #require(InputPrice.forModel(" GPT-6-ASTRA "))
    let values = try #require(TokenUsage(usage()))
    #expect(abs((price.cost(values) ?? -1) - 0.0131) < 1e-12)
    let range = try #require(price.savings(tokens: 100, usage: values))
    #expect(abs(range.lowerBound - 0.0002) < 1e-12)
    #expect(abs(range.upperBound - 0.002) < 1e-12)
    #expect(price.cost(try #require(TokenUsage(usage(cached: 1100)))) == nil)
    #expect(price.cost(try #require(TokenUsage(usage(200_001)))) == nil)
    #expect(price.savings(tokens: 1001, usage: values) == nil)
    #expect(price.savings(tokens: 100, usage: try #require(TokenUsage(usage(write: 1)))) == nil)
    #expect(abs((price.cost(try #require(TokenUsage(usage(write: 100)))) ?? -1) - 0.0136) < 1e-12)
    #expect(InputPrice.forModel("gpt-6-astra-2026") == nil)
    #expect(InputPrice.forModel("gpt-6-sol") == nil)
    #expect(InputPrice.forModel("gpt-5.3-codex")?.cost(values) == nil)
    #expect(InputPrice.forModel("gpt-5.3-codex")?.savings(tokens: 100, usage: values) != nil)
}

@Test func incompleteAndInvalidUsageIsUnknown() {
    for key in usage().keys {
        var raw = usage()
        raw.removeValue(forKey: key)
        #expect(TokenUsage(raw) == nil)
        for value in [-1, true, 1.5, Double.infinity, "100"] as [Any] {
            raw[key] = value
            #expect(TokenUsage(raw) == nil)
        }
    }
}

@Test func responsesUseTheirOwnModelAndDeduplicate() throws {
    let header = try history([
        response("r1"), response("r1"),
        ["type": "turn_context", "payload": ["turn_id": "t2", "model": "gpt-5.6-sol"]],
        response("r2", turn: "t2"), response("child", thread: "child"),
        response("missing", turn: "missing"),
    ])
    #expect(header.responses.count == 3)
    #expect(header.responses.map(\.model) == ["gpt-6-astra", "gpt-5.6-sol", nil])
    #expect(header.historyIssues == 1)
    let snapshot = SavingsSummary(sessions: [header, header], project: URL(fileURLWithPath: "/fixture"), now: historyNow, pricingMode: .actual).current7
    #expect(snapshot.responseCount == 3)
    #expect(snapshot.costCoverage == 3)
    #expect(snapshot.actualCostCoverage == 2)
    #expect(snapshot.savingsCoverage == 2)
    #expect(snapshot.tokens == 300)
    #expect(abs((snapshot.actualCost ?? -1) - 0.01834) < 1e-12)
    #expect(abs((snapshot.cost ?? -1) - 0.0393) < 1e-12)
}

@Test func contextEvidenceStopsAndCanResume() throws {
    for interruption in [
        ["type": "compacted", "payload": [:]],
        ["type": "event_msg", "payload": ["type": "item_completed", "item": ["type": "ContextCompaction"]]],
        ["type": "world_state", "payload": ["full": true]],
    ] {
        let header = try history([response("before"), interruption, response("unknown"),
            context(String(repeating: "b", count: 200)), response("restored")])
        #expect(header.responses.map { $0.targets[.skillCatalog] } == [100, nil, 50])
        let snapshot = SavingsSummary(sessions: [header], project: URL(fileURLWithPath: "/fixture"), now: historyNow).all30
        #expect(snapshot.tokens == 150)
        #expect(snapshot.savingsCoverage == 2)
        #expect(snapshot.actualCostCoverage == 3)
    }
    let broken = try history([response("before"), response("unknown")], brokenAfter: 5)
    #expect(broken.responses.last?.targets.isEmpty == true)
}

@Test func fallbackIsPartialAndNeverAddedToFormalUsage() throws {
    func fallback(_ amount: Int, last: Bool = false) -> [String: Any] {
        ["type": "event_msg", "payload": ["type": "token_count",
         "info": [last ? "last_token_usage" : "total_token_usage": usage(amount)]]]
    }
    let cumulative = try history([fallback(1000), fallback(2000)])
    #expect(cumulative.responses.count == 1)
    #expect(cumulative.responses.first?.usage == nil)
    let last = try history([fallback(1000), fallback(1000, last: true), fallback(1000, last: true)])
    #expect(last.responses.count == 2)
    let formal = try history([fallback(1000), response("r1")])
    #expect(formal.responses.count == 1)
    #expect(formal.responses.first?.id == "r1")
    let snapshot = SavingsSummary(sessions: [cumulative], project: URL(fileURLWithPath: "/fixture"), now: historyNow).all30
    #expect(snapshot.actualCost == nil)
    #expect(snapshot.savingsUSD == nil)
}

@Test func rollingWindowsUseResponseTimesAndPartialCoverage() throws {
    var partial = usage(); partial.removeValue(forKey: "cache_write_input_tokens")
    let header = try history([
        response("older", date: historyNow.addingTimeInterval(-20 * 86_400)),
        response("recent"), response("partial", values: partial),
        response("expired", date: historyNow.addingTimeInterval(-31 * 86_400)),
        response("future", date: historyNow.addingTimeInterval(86_400)),
    ])
    let summary = SavingsSummary(sessions: [header], project: URL(fileURLWithPath: "/fixture"), now: historyNow)
    #expect(summary.current7.responseCount == 2)
    #expect(summary.current7.actualCostCoverage == 1)
    #expect(summary.current30.responseCount == 3)
    #expect(summary.current30.actualCostCoverage == 2)
    #expect(summary.current30.tokens == 200)
    #expect(summary.current30.savingsCoverage == 2)
}


@Test func ordinalGapsAndTruncatedSnapshotsInvalidateTargets() throws {
    var gap = response("gap")
    gap["ordinal"] = 20
    let broken = try history([response("before"), gap])
    #expect(broken.responses.last?.targets.isEmpty == true)
    let truncated = try history([response("before"),
        ["type": "world_state", "payload": ["state": ["host_skills": ["body": "partial", "truncated": true]]]],
        response("after")])
    #expect(truncated.responses.last?.targets[.skillCatalog] == nil)
}

@Test func cacheBoundsRespectActualPartitions() throws {
    let price = InputPrice.maximum
    let fullyCached = try #require(TokenUsage(usage(cached: 1000)))
    let cachedRange = try #require(price.savings(tokens: 100, usage: fullyCached))
    #expect(cachedRange.lowerBound == cachedRange.upperBound)
    #expect(abs(cachedRange.lowerBound - 0.0002) < 1e-12)
    let uncached = try #require(TokenUsage(usage(cached: 0)))
    let ordinaryRange = try #require(price.savings(tokens: 100, usage: uncached))
    #expect(ordinaryRange.lowerBound == ordinaryRange.upperBound)
    #expect(abs(ordinaryRange.lowerBound - 0.002) < 1e-12)
}

@Test func partialTargetKnowledgeDoesNotInventZeroSavings() throws {
    let header = try history([response("before"), ["type": "compacted", "payload": [:]],
        context("memory", kind: "memories.instructions"), response("after")])
    let snapshot = SavingsSummary(sessions: [header], project: URL(fileURLWithPath: "/fixture"), now: historyNow).all7
    #expect(snapshot.savingsCoverage == 2)
    #expect(snapshot.byTarget[.skillCatalog] == 100)
    let onlyUnknown = try history([["type": "compacted", "payload": [:]], response("unknown")])
    let unknown = SavingsSummary(sessions: [onlyUnknown], project: URL(fileURLWithPath: "/fixture"), now: historyNow).all7
    #expect(unknown.byTargetUSD[.skillCatalog] == nil)
    #expect(unknown.savingsUSD == nil)
    #expect(unknown.actualCost != nil)
}

@Test func defaultPricingUsesMaximumAndActualModeKeepsItsOwnCoverage() throws {
    let header = try history([
        ["type": "turn_context", "payload": ["turn_id": "cheap", "model": "gpt-5.6-sol"]],
        response("known", turn: "cheap"), response("unknown", turn: "missing"),
    ])
    let project = URL(fileURLWithPath: "/fixture")
    let maximum = SavingsSummary(sessions: [header], project: project, now: historyNow)
    let actual = SavingsSummary(sessions: [header], project: project, now: historyNow, pricingMode: .actual)
    for (maxSnapshot, actualSnapshot) in zip(
        [maximum.current7, maximum.current30, maximum.all7, maximum.all30],
        [actual.current7, actual.current30, actual.all7, actual.all30]) {
        let maxRange = try #require(maxSnapshot.savingsUSD)
        let actualRange = try #require(actualSnapshot.savingsUSD)
        #expect(abs(maxRange.lowerBound - 0.0004) < 1e-12)
        #expect(abs(maxRange.upperBound - 0.004) < 1e-12)
        #expect(abs(actualRange.lowerBound - 0.00008) < 1e-12)
        #expect(abs(actualRange.upperBound - 0.0008) < 1e-12)
        #expect(maxSnapshot.savingsCoverage == 2)
        #expect(actualSnapshot.savingsCoverage == 1)
        #expect(maxSnapshot.byTargetUSD[.skillCatalog] == maxRange)
        #expect(actualSnapshot.byTargetUSD[.skillCatalog] == actualRange)
        #expect(maxSnapshot.tokens == actualSnapshot.tokens)
        #expect(maxSnapshot.costCoverage == 2)
        #expect(actualSnapshot.actualCostCoverage == 1)
    }
}
