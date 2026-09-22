import Foundation

public struct ScanResult: Sendable {
    public let sessions: [SessionHeader]
    public let warning: String?
}

/// Metadata polling avoids reparsing unchanged logs; no transcript text is retained.
public actor SessionRepository {
    private struct Entry { let size: Int; let modified: Date; let header: SessionHeader? }
    private var cache: [String: Entry] = [:]
    public init() {}

    public func scan(codexHome: URL, project: URL) throws -> ScanResult {
        let root = codexHome.appendingPathComponent("sessions", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return ScanResult(sessions: [], warning: "尚未找到 Codex sessions 目录")
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
        let selected = Array(files.prefix(500))
        let paths = Set(selected.map { $0.0.path })
        cache = cache.filter { paths.contains($0.key) }
        for (url, size, modified) in selected {
            if let cached = cache[url.path], cached.size == size && cached.modified == modified { continue }
            do {
                cache[url.path] = Entry(size: size, modified: modified, header: try HeaderParser.read(url))
            } catch {
                cache.removeValue(forKey: url.path)
                hadError = true
            }
        }
        let projectPath = canonicalPath(project)
        let ordered = cache.values.compactMap(\.header).filter { $0.project == projectPath }
            .sorted { $0.date > $1.date }
        var ids = Set<String>()
        let unique = ordered.filter { ids.insert($0.id).inserted }
        let limited = files.count > 500 || visited > 20_000
        let warning = hadError ? "部分日志无法读取或扫描已达上限；结果可能不完整"
            : limited ? "仅检查最近修改的 500 个日志文件；更早的项目记录可能未包含" : nil
        return ScanResult(sessions: Array(unique.prefix(30)), warning: warning)
    }
}
