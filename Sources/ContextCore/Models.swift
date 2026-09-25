import Foundation

public enum ControlTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case skillCatalog, memory, plugins
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .skillCatalog: "自动技能目录"
        case .memory: "记忆说明"
        case .plugins: "Plugins 功能"
        }
    }
    public var table: String {
        switch self {
        case .skillCatalog: "skills"
        case .memory: "memories"
        case .plugins: "features"
        }
    }
    public var key: String {
        switch self {
        case .skillCatalog: "include_instructions"
        case .memory: "use_memories"
        case .plugins: "plugins"
        }
    }
    public var kinds: [String] {
        switch self {
        case .skillCatalog: ["host_skills.instructions"]
        case .memory: ["memories.instructions"]
        case .plugins: ["plugins.usage_instructions", "plugins.recommendations"]
        }
    }
    public var isGlobal: Bool { self != .skillCatalog }
    public var consequence: String {
        switch self {
        case .skillCatalog: "仅修改所选项目。隐藏自动技能目录后，模型可能无法自动发现技能；显式选择的技能仍可能注入。"
        case .memory: "修改用户级配置，影响其他项目的新会话。停止注入记忆说明，不删除记忆文件。项目或宿主覆盖仍可能生效。"
        case .plugins: "修改用户级配置，影响其他项目的新会话。会同时关闭插件功能、工具与技能发现，不只是隐藏推荐列表。"
        }
    }
}

public struct ContextBlock: Identifiable, Sendable {
    public let kind: String
    public let role: String
    public let tokens: Int
    public var id: String { role + ":" + kind }
    public var title: String {
        switch kind {
        case "host_skills.instructions": "自动技能目录"
        case "memories.instructions": "记忆说明"
        case "plugins.usage_instructions": "插件使用说明"
        case "plugins.recommendations": "推荐插件"
        case "permissions.instructions": "权限说明"
        case "apps.instructions": "Apps 说明"
        case "collaboration_mode.instructions": "协作模式"
        case "environments.environment_context": "运行环境"
        case "agents_md.instructions": "AGENTS.md"
        case "tools.deferred_namespaces": "延迟工具说明"
        default: kind
        }
    }
}

public struct SessionHeader: Identifiable, Sendable {
    public var id: String
    public var project: String
    public var date: Date
    public var version: String
    public var model: String?
    public var source: String
    public var file: URL
    public var blocks: [ContextBlock]
    public var complete: Bool
    public var issue: String?
    public var tokens: Int { blocks.reduce(0) { $0 + $1.tokens } }
    public func contains(_ target: ControlTarget) -> Bool {
        blocks.contains { target.kinds.contains($0.kind) }
    }
}

public enum ContextError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let message): message }
    }
}

public func canonicalPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
}
