import Foundation

/// Reads only a bounded initial snapshot. Literal tags in normal text are not evidence.
public enum HeaderParser {
    public static let byteLimit = 8 * 1024 * 1024

    public static func read(_ url: URL) throws -> SessionHeader? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        var result: SessionHeader?
        while data.count < byteLimit {
            let chunk = try handle.read(upToCount: min(65_536, byteLimit - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
            // A chunk may split a JSON record. Only complete lines can yield a terminal decision.
            guard let end = data.lastIndex(of: 10) else { continue }
            var finished = false
            result = parse(Data(data.prefix(through: end)), file: url, finished: &finished)
            if finished { break }
        }
        return result
    }

    public static func parse(_ data: Data, file: URL) -> SessionHeader? {
        var finished = false
        return parse(data, file: file, finished: &finished)
    }

    private static func parse(_ data: Data, file: URL, finished: inout Bool) -> SessionHeader? {
        var header: SessionHeader?
        var expected = 0
        var roles = Set<String>()
        var fullState = false
        var counts: [String: (kind: String, role: String, characters: Int)] = [:]
        for line in data.split(separator: 10) {
            finished = true
            guard !line.allSatisfy({ $0 == 13 || $0 == 32 || $0 == 9 }) else { continue }
            guard let item = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                  let type = item["type"] as? String,
                  let payload = item["payload"] as? [String: Any] else {
                header?.issue = "日志尚未写完或格式无法识别"
                return header
            }
            if type == "session_meta", header == nil {
                guard let id = (payload["id"] ?? payload["session_id"]) as? String,
                      let cwd = payload["cwd"] as? String else { return nil }
                let time = (payload["timestamp"] ?? item["timestamp"]) as? String ?? ""
                header = SessionHeader(id: id, project: canonicalPath(URL(fileURLWithPath: cwd)),
                    date: date(time) ?? .distantPast, version: payload["cli_version"] as? String ?? "未知",
                    source: payload["source"] as? String ?? "未知", file: file, blocks: [], complete: false,
                    issue: "未找到完整初始会话头")
                let base = payload["history_base"] as? [String: Any]
                if payload["forked_from_id"] != nil || payload["parent_thread_id"] != nil
                    || (base?["end_ordinal_exclusive"] as? Int ?? 0) > 0 {
                    header?.issue = "继承或分页增量，不能证明 block 缺席"
                    return header
                }
            }
            guard item["ordinal"] as? Int == expected, header != nil else {
                header?.issue = "会话记录缺少连续的 ordinal-zero 初始证据"
                return header
            }
            expected += 1
            if type == "compacted" {
                header?.issue = "初始证据之前已发生压缩"
                return header
            }
            if type == "world_state", payload["full"] as? Bool == true { fullState = true }
            if type == "turn_context" {
                let complete = fullState && roles.contains("developer") && roles.contains("user")
                    && header?.version != "未知" && header?.date != .distantPast
                header?.complete = complete
                if complete { header?.issue = nil }
                return header
            }
            finished = false
            guard type == "response_item", let role = payload["role"] as? String,
                  ["developer", "user"].contains(role) else { continue }
            let metadata = payload["internal_chat_message_metadata_passthrough"] as? [String: Any]
            guard let kinds = metadata?["content_item_kinds"] as? [String],
                  let content = payload["content"] as? [[String: Any]], kinds.count == content.count else {
                finished = true
                header?.issue = "缺少可信 content item metadata"
                return header
            }
            roles.insert(role)
            for (kind, part) in zip(kinds, content) {
                guard let text = part["text"] as? String else {
                    finished = true
                    header?.issue = "无法识别会话头内容"
                    return header
                }
                let key = role + ":" + kind
                counts[key] = (kind, role, (counts[key]?.characters ?? 0) + text.count)
            }
            header?.blocks = counts.values.map {
                ContextBlock(kind: $0.kind, role: $0.role, characters: $0.characters)
            }.sorted { $0.kind < $1.kind }
        }
        return header
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
