import Foundation

public struct ScanResult: Sendable {
    public let sessions: [SessionHeader]
    public let recentSessions: [SessionHeader]
    public let warning: String?
}

/// Metadata polling avoids reparsing unchanged logs; no transcript text is retained.
public actor SessionRepository {
    private struct Entry { let size: Int; let modified: Date; let header: SessionHeader? }
    private var cache: [String: Entry] = [:]
    public init() {}

    public func scan(codexHome: URL, project: URL, now: Date = Date()) throws -> ScanResult {
        let root = codexHome.appendingPathComponent("sessions", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return ScanResult(sessions: [], recentSessions: [], warning: "尚未找到 Codex sessions 目录")
        }
        var hadError = false
        guard let iterator = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles], errorHandler: { _, _ in hadError = true; return true }) else {
            throw ContextError.message("无法读取 Codex 会话目录")
        }
        var files: [(URL, Int, Date)] = []
        var visited = 0
        for case let url as URL in iterator {
            visited += 1
            if visited > 20_000 { hadError = true; break }
            guard url.pathExtension == "jsonl" else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isRegularFile == true else { continue }
            files.append((url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast))
        }
        files.sort { $0.2 > $1.2 }
        let cutoff = now.addingTimeInterval(-30 * 86_400)
        let selected = files.enumerated().compactMap { index, file in
            index < 500 || file.2 >= cutoff ? file : nil
        }
        let paths = Set(selected.map { $0.0.path })
        cache = cache.filter { paths.contains($0.key) }
        for (url, size, modified) in selected {
            if let cached = cache[url.path], cached.size == size && cached.modified == modified { continue }
            do {
                var header = try HeaderParser.read(url)
                if var parsed = header {
                    let history = try HistoryParser.read(url, header: parsed)
                    parsed.responses = history.responses
                    parsed.historyIssues = history.issues
                    header = parsed
                }
                cache[url.path] = Entry(size: size, modified: modified, header: header)
            } catch {
                cache.removeValue(forKey: url.path)
                hadError = true
            }
        }
        let ordered = cache.values.sorted {
            let lhs = $0.header?.lastActivity ?? .distantPast
            let rhs = $1.header?.lastActivity ?? .distantPast
            if lhs != rhs { return lhs > rhs }
            if $0.modified != $1.modified { return $0.modified > $1.modified }
            return ($0.header?.file.path ?? "") < ($1.header?.file.path ?? "")
        }.compactMap(\.header)
        var ids = Set<String>()
        let unique = ordered.filter { ids.insert($0.sessionID ?? $0.id).inserted }
        let projectPath = canonicalPath(project)
        let recent = unique.filter {
            ($0.date >= cutoff && $0.date <= now) || $0.responses.contains { $0.date >= cutoff && $0.date <= now }
        }
        let limited = selected.count < files.count
        let warning = hadError ? "部分日志无法读取或扫描已达上限；结果可能不完整"
            : limited ? "较早会话仅检查最近修改的 500 个日志；近 30 天统计按文件修改时间筛选"
            : unique.contains(where: { $0.historyIssues > 0 }) ? "部分响应有重复、用量缺失或上下文证据中断；请结合计价覆盖数查看" : nil
        return ScanResult(sessions: Array(unique.filter { $0.project == projectPath }.prefix(30)),
            recentSessions: recent, warning: warning)
    }
}
