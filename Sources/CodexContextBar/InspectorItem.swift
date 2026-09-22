import ContextCore
import Foundation

struct InspectorItem: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let target: ControlTarget?

    static let primary: [InspectorItem] = [
        .init(id: "host_skills.instructions", title: "自动技能目录", symbol: "doc.text", target: .skillCatalog),
        .init(id: "memories.instructions", title: "记忆说明", symbol: "doc.text", target: .memory),
        .init(id: "plugins.usage_instructions", title: "插件说明", symbol: "puzzlepiece.extension", target: .plugins),
        .init(id: "plugins.recommendations", title: "推荐插件", symbol: "list.bullet", target: nil),
    ]

    static func items(in session: SessionHeader?) -> [InspectorItem] {
        primary + (session?.blocks ?? []).filter { block in !primary.contains { $0.id == block.kind } }
            .reduce(into: [InspectorItem]()) { result, block in
                if !result.contains(where: { $0.id == block.kind }) {
                    result.append(.init(id: block.kind, title: block.title, symbol: "doc.plaintext", target: nil))
                }
            }
    }

    func characters(in session: SessionHeader?) -> Int? {
        guard let session, session.complete || session.blocks.contains(where: { $0.kind == id }) else { return nil }
        return session.blocks.filter { $0.kind == id }.reduce(0) { $0 + $1.characters }
    }

    func observation(in session: SessionHeader?) -> String {
        guard let session else { return "未知" }
        if !session.complete { return session.blocks.contains { $0.kind == id } ? "部分观测" : "未知" }
        return session.blocks.contains { $0.kind == id } ? "存在" : "未观察到"
    }

    var scope: String {
        guard let target else { return "仅观察" }
        return target.isGlobal ? "用户级 · 影响所有项目" : "仅当前项目"
    }

    var consequence: String {
        switch target {
        case .skillCatalog: "关闭目录会减少自动技能发现说明，显式选择仍可使用。"
        case .memory: "停止注入记忆说明，不会删除记忆文件；影响其他项目的新任务。"
        case .plugins: "关闭 Plugins 会同时关闭插件功能、工具与技能发现。"
        case nil where id == "plugins.recommendations": "Desktop 中尚未确认可靠的独立关闭方式。关闭 Plugins 会影响整个插件功能。"
        case nil: "此项来自会话头观测，当前仅提供证据查看。"
        }
    }
}
