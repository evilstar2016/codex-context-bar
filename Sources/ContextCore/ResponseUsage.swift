import Foundation
import CoreFoundation

public struct TokenUsage: Sendable {
    public let input: Int
    public let cached: Int
    public let cacheWrite: Int
    public let output: Int
    public let reasoning: Int
    public let total: Int

    init?(_ raw: [String: Any]) {
        func count(_ key: String) -> Int? {
            guard let value = raw[key] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                  value.doubleValue.isFinite, value.doubleValue >= 0,
                  value.doubleValue < Double(Int.max), value.doubleValue.rounded() == value.doubleValue else { return nil }
            return value.intValue
        }
        guard let input = count("input_tokens"), let cached = count("cached_input_tokens"),
              let cacheWrite = count("cache_write_input_tokens"), let output = count("output_tokens"),
              let reasoning = count("reasoning_output_tokens"), let total = count("total_tokens") else { return nil }
        self.input = input; self.cached = cached; self.cacheWrite = cacheWrite
        self.output = output; self.reasoning = reasoning; self.total = total
    }

    public var validPartitions: Bool { cached <= input && cacheWrite <= input - cached }
}

public struct ResponseUsage: Sendable {
    public let id: String
    public let date: Date
    public let model: String?
    /// Nil means incomplete or fallback usage, never zero usage.
    public let usage: TokenUsage?
    public let targets: [ControlTarget: Int]
}

/// Streams history separately from the bounded initial header used for configuration evidence.
public enum HistoryParser {
    public static func read(_ url: URL, header: SessionHeader) throws -> (responses: [ResponseUsage], issues: Int) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var parser = Parser(header: header)
        var pending = Data()
        var dropping = false
        while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
            pending.append(chunk)
            while let end = pending.firstIndex(of: 10) {
                if !dropping { parser.consume(Data(pending[..<end])) }
                pending.removeSubrange(...end)
                dropping = false
            }
            // Bound memory for malformed or unexpectedly large records.
            if pending.count > HeaderParser.byteLimit {
                pending.removeAll(keepingCapacity: true)
                dropping = true
                parser.invalidate()
            }
        }
        if !pending.isEmpty || dropping { parser.invalidate() }
        return (parser.formalSeen ? parser.responses : parser.fallback + (parser.lastCumulative.map { [$0] } ?? []), parser.issues)
    }

    private struct Parser {
        let header: SessionHeader
        var responses: [ResponseUsage] = []
        var fallback: [ResponseUsage] = []
        var lastCumulative: ResponseUsage?
        var formalSeen = false
        var seen = Set<String>()
        var models: [String: String] = [:]
        var targets: [ControlTarget: Int] = [:]
        var previousOrdinal: Int?
        var responded = false
        var initialTurnSeen = false
        var issues = 0
        var lineNumber = 0
        let dates = ISO8601DateFormatter()
        let fractionalDates: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        mutating func invalidate() { targets.removeAll(); issues += 1 }

        mutating func consume(_ line: Data) {
            lineNumber += 1
            if line.allSatisfy({ $0 == 13 || $0 == 32 || $0 == 9 }) { return }
            guard let record = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                  let type = record["type"] as? String, let payload = record["payload"] as? [String: Any] else {
                invalidate(); return
            }
            let ordinal = record["ordinal"] as? Int
            if let previousOrdinal, previousOrdinal == Int.max || ordinal != previousOrdinal + 1 { invalidate() }
            previousOrdinal = ordinal
            if type == "compacted" || (type == "event_msg" && payload["type"] as? String == "item_completed"
                && (payload["item"] as? [String: Any])?["type"] as? String == "ContextCompaction") { invalidate() }
            if type == "world_state" {
                if responded && payload["full"] as? Bool == true { targets.removeAll() }
                if let state = payload["state"] as? [String: Any] {
                    if state["host_skills"] is NSNull { targets.removeValue(forKey: .skillCatalog) }
                    if let skills = state["host_skills"] as? [String: Any] {
                        if let body = skills["body"] as? String, skills["truncated"] as? Bool != true {
                            targets[.skillCatalog] = TokenEstimate.count(body)
                        } else { targets.removeValue(forKey: .skillCatalog) }
                    }
                }
            }
            if type == "response_item", let role = payload["role"] as? String, ["developer", "user"].contains(role) {
                let metadata = payload["internal_chat_message_metadata_passthrough"] as? [String: Any]
                if let kinds = metadata?["content_item_kinds"] as? [String] {
                    guard let parts = payload["content"] as? [[String: Any]], parts.count == kinds.count else { invalidate(); return }
                    var texts: [ControlTarget: String] = [:]
                    for (kind, part) in zip(kinds, parts) {
                        guard let target = ControlTarget.allCases.first(where: { $0.kinds.contains(kind) }) else { continue }
                        guard let text = part["text"] as? String else { invalidate(); return }
                        texts[target, default: ""] += text
                    }
                    for (target, text) in texts { targets[target] = TokenEstimate.count(text) }
                }
            }
            if type == "turn_context", !initialTurnSeen {
                // Only the independently validated complete initial header proves absence.
                if header.complete {
                    for target in ControlTarget.allCases where targets[target] == nil { targets[target] = 0 }
                }
                initialTurnSeen = true
            }
            if type == "turn_context", let turn = payload["turn_id"] as? String {
                models[turn] = payload["model"] as? String
            }
            let formal = type == "token_usage_record"
            if formal { formalSeen = true }
            guard formal || (type == "event_msg" && payload["type"] as? String == "token_count") else { return }
            responded = true
            let thread = (payload["thread_id"] ?? payload["session_id"]) as? String
            guard thread == header.id || (!formal && thread == nil) else { return }
            guard let timestamp = record["timestamp"] as? String,
                  let date = fractionalDates.date(from: timestamp) ?? dates.date(from: timestamp) else { issues += 1; return }
            let model = (payload["turn_id"] as? String).flatMap { models[$0] }
            if formal {
                guard let id = payload["response_id"] as? String, !id.isEmpty else { issues += 1; return }
                guard seen.insert(id).inserted else { issues += 1; return }
                let usage = (payload["usage"] as? [String: Any]).flatMap(TokenUsage.init)
                if usage == nil || usage?.validPartitions == false { issues += 1 }
                responses.append(ResponseUsage(id: id, date: date, model: model, usage: usage, targets: targets))
            } else if let info = payload["info"] as? [String: Any] {
                let response = ResponseUsage(id: "fallback-\(lineNumber)", date: date, model: model, usage: nil, targets: targets)
                if info["last_token_usage"] is [String: Any] { fallback.append(response); lastCumulative = nil }
                else if info["total_token_usage"] is [String: Any], fallback.isEmpty { lastCumulative = response }
            }
        }
    }
}
