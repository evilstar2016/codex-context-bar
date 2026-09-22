import CryptoKit
import Darwin
import Foundation

public struct ConfigPreview: Identifiable, Sendable {
    public let id: UUID
    public let target: ControlTarget
    public let enabled: Bool
    public let file: URL
    public let before: Bool?
    public let afterText: String
    public let fingerprint: String
    public let baseline: SessionHeader
}

public struct ConfigOperation: Codable, Identifiable, Sendable {
    public let id: UUID
    public let target: ControlTarget
    public let enabled: Bool
    public let before: Bool?
    public let project: String
    public let configPath: String
    public let createdAt: Date
    public let baselineID: String
    public let source: String
    public let fingerprint: String
    public var restored: Bool
}

public struct Verification: Sendable {
    public let matched: Bool?
    public let message: String
    public let sessionID: String?
}

public struct OperationStore: Sendable {
    public let directory: URL
    public let codexHome: URL
    public init(directory: URL, codexHome: URL) {
        self.directory = directory
        self.codexHome = codexHome
    }

    public func configURL(project: URL, target: ControlTarget) -> URL {
        (target.isGlobal ? codexHome : project.appendingPathComponent(".codex"))
            .appendingPathComponent("config.toml")
    }

    public func preview(project: URL, baseline: SessionHeader, target: ControlTarget, enabled: Bool) throws -> ConfigPreview {
        guard baseline.complete, baseline.project == canonicalPath(project) else {
            throw ContextError.message("请选择当前项目的完整初始会话头")
        }
        let file = configURL(project: project, target: target)
        try rejectSymlinks(file)
        let original = try read(file)
        let current = try ConfigEditor.value(in: original ?? "", target: target)
        guard current != enabled else { throw ContextError.message("该文件中的目标键已经是此值") }
        let after = try ConfigEditor.edit(original ?? "", target: target, value: enabled)
        return ConfigPreview(id: UUID(), target: target, enabled: enabled, file: file, before: current,
            afterText: after, fingerprint: try fingerprint(project), baseline: baseline)
    }

    public func apply(_ preview: ConfigPreview, project: URL) throws -> ConfigOperation {
        try locked {
            guard preview.baseline.project == canonicalPath(project),
                  preview.file == configURL(project: project, target: preview.target),
                  try fingerprint(project) == preview.fingerprint else {
                throw ContextError.message("配置已变化，请重新预览")
            }
            let old = try read(preview.file)
            let nextFingerprint = try fingerprint(project, replacing: (preview.file, preview.afterText))
            let operation = ConfigOperation(id: preview.id, target: preview.target, enabled: preview.enabled,
                before: preview.before, project: canonicalPath(project), configPath: preview.file.path,
                createdAt: Date(), baselineID: preview.baseline.id, source: preview.baseline.source,
                fingerprint: nextFingerprint, restored: false)
            // Journal first: a crash leaves an inspectable operation, never an untracked edit.
            try save(operation)
            do { try write(preview.afterText, to: preview.file, expected: old) }
            catch { try? FileManager.default.removeItem(at: operationURL(operation.id)); throw error }
            return operation
        }
    }

    public func operations(project: URL) throws -> [ConfigOperation] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(ConfigOperation.self, from: Data(contentsOf: $0)) }
            .filter { $0.project == canonicalPath(project) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func undo(_ operation: ConfigOperation, project: URL) throws {
        try locked {
            var current = try JSONDecoder().decode(ConfigOperation.self, from: Data(contentsOf: operationURL(operation.id)))
            let file = configURL(project: project, target: current.target)
            guard !current.restored, current.project == canonicalPath(project), current.configPath == file.path else {
                throw ContextError.message("操作已撤销或不属于此项目")
            }
            let original = try read(file)
            guard try ConfigEditor.value(in: original ?? "", target: current.target) == current.enabled else {
                throw ContextError.message("目标键已被其他操作修改；拒绝覆盖")
            }
            let after = try ConfigEditor.edit(original ?? "", target: current.target, value: current.before)
            try write(after, to: file, expected: original)
            current.restored = true
            try save(current)
        }
    }

    public func verify(_ operation: ConfigOperation, project: URL, sessions: [SessionHeader]) throws -> Verification {
        guard !operation.restored else {
            return Verification(matched: nil, message: "已撤销；恢复效果仍需新会话观察", sessionID: nil)
        }
        guard operation.project == canonicalPath(project), try fingerprint(project) == operation.fingerprint else {
            return Verification(matched: nil, message: "配置已变化，原操作无法继续验证", sessionID: nil)
        }
        guard let fresh = sessions.filter({
            $0.complete && $0.project == operation.project && $0.date > operation.createdAt
                && $0.id != operation.baselineID && $0.source == operation.source
        }).max(by: { $0.date < $1.date }) else {
            return Verification(matched: nil, message: "待验证：请在 Codex Desktop 的同一项目目录新建任务", sessionID: nil)
        }
        let present = fresh.contains(operation.target)
        let matches = present == operation.enabled
        return Verification(matched: matches,
            message: matches ? "新任务观测符合预期（不证明唯一因果）" : "新任务观测不符合预期；可能存在配置覆盖或功能条件",
            sessionID: fresh.id)
    }

    private func fingerprint(_ project: URL, replacing: (URL, String)? = nil) throws -> String {
        var paths: Set<String> = [codexHome.appendingPathComponent("config.toml").path]
        var directory = project.standardizedFileURL
        while true {
            paths.insert(directory.appendingPathComponent(".codex/config.toml").path)
            if directory.path == "/" { break }
            directory.deleteLastPathComponent()
        }
        let parts = try paths.sorted().map { path -> String in
            let value = path == replacing?.0.path ? replacing?.1 : try read(URL(fileURLWithPath: path))
            return path + "\u{0}" + (value.map { "present:" + Self.hash($0) } ?? "missing")
        }
        return Self.hash(parts.joined(separator: "\n"))
    }

    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func read(_ url: URL) throws -> String? {
        try rejectSymlinks(url)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func rejectSymlinks(_ url: URL) throws {
        var cursor = url.standardizedFileURL
        // Foundation normalizes /private/var, /private/tmp and /private/etc to these OS aliases.
        let systemAliases: Set<String> = ["/var", "/tmp", "/etc"]
        while cursor.path != "/", !systemAliases.contains(cursor.path) {
            if (try? cursor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw ContextError.message("配置路径包含符号链接，请使用真实目录：\(cursor.path)")
            }
            cursor.deleteLastPathComponent()
        }
    }

    private func operationURL(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".json") }
    private func save(_ operation: ConfigOperation) throws {
        let data = try JSONEncoder().encode(operation)
        let url = operationURL(operation.id)
        try write(String(decoding: data, as: UTF8.self), to: url, expected: read(url))
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        try rejectSymlinks(directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let lockPath = directory.appendingPathComponent("operations.lock").path
        let fd = open(lockPath, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw ContextError.message("无法创建配置操作锁") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw ContextError.message("另一项配置操作正在执行") }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    private func write(_ text: String, to url: URL, expected: String?) throws {
        try rejectSymlinks(url)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let temporary = parent.appendingPathComponent(".context-bar-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw ContextError.message("无法创建临时配置文件") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        try handle.write(contentsOf: Data(text.utf8))
        try handle.synchronize()
        guard try read(url) == expected else { throw ContextError.message("配置发生并发修改；请重新预览") }
        if let mode = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber {
            guard fchmod(fd, mode_t(mode.uint16Value)) == 0 else { throw ContextError.message("无法保留配置文件权限") }
        }
        guard rename(temporary.path, url.path) == 0 else { throw ContextError.message("无法原子替换配置文件") }
    }
}
