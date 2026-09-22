import AppKit
import ContextCore
import SwiftUI

struct Dashboard: View {
    @Bindable var model: AppModel
    @State private var undoCandidate: ConfigOperation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("上下文，心中有数").font(.largeTitle.bold())
                        Text("观察会话头 · 预览配置 · 验证新任务").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("选择项目", action: model.chooseProject)
                    Button { Task { await model.refresh() } } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }.disabled(model.refreshing)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.project?.path ?? "尚未选择项目").font(.callout.monospaced()).textSelection(.enabled)
                    HStack {
                        Text("Codex：\(model.codexHome.path)").font(.caption).foregroundStyle(.secondary)
                        Button("更改", action: model.chooseCodexHome).buttonStyle(.link)
                    }
                    if let date = model.lastRefresh {
                        Text("上次检查 \(date.formatted(date: .omitted, time: .standard)) · 最近 500 个日志，最多展示 30 个项目会话")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let warning = model.warning { notice(warning, symbol: "exclamationmark.triangle") }
                if model.sessions.isEmpty {
                    ContentUnavailableView("尚无可读的会话记录", systemImage: "doc.text.magnifyingglass",
                        description: Text("选择项目后，在 Codex Desktop 使用该目录新建任务。应用只读取本机 sessions 日志。"))
                } else {
                    Picker("观察会话", selection: $model.selectedID) {
                        ForEach(model.sessions) { session in
                            Text("\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(session.id.prefix(8)) · \(session.complete ? "完整" : "不完整")")
                                .tag(Optional(session.id))
                        }
                    }
                    if let session = model.selected {
                        sessionPanel(session)
                        controls(session)
                    }
                }
                if !model.operations.isEmpty { operationPanel }
                notice("配置写入不等于会话生效。请手动新建 Desktop task，应用会匹配同目录、同 source 的完整新会话头；无法证明 Desktop 宿主来源或每次实际请求的完整上下文。", symbol: "info.circle")
                Text("兼容依据：Desktop runtime 0.154.0-alpha.6.2（2026-09-17—18）。其它版本需要重新观察。当前展示字符数，未实现精确 Token 计数和账单节省估算。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .frame(minWidth: 720, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $model.preview) { preview in previewPanel(preview) }
        .alert("无法完成操作", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert("撤销这次配置修改？", isPresented: Binding(get: { undoCandidate != nil }, set: { if !$0 { undoCandidate = nil } })) {
            Button("取消", role: .cancel) { undoCandidate = nil }
            Button("撤销") { if let operation = undoCandidate { model.undo(operation) }; undoCandidate = nil }
        } message: { Text("只恢复本次目标键，保留其他修改。恢复效果仍需新会话观察。") }
    }

    private func sessionPanel(_ session: SessionHeader) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(session.complete ? "完整初始会话头" : "证据不足", systemImage: session.complete ? "checkmark.seal" : "questionmark.circle")
                        .font(.headline).foregroundStyle(session.complete ? .green : .orange)
                    Spacer()
                    Text("\(session.characters.formatted()) 字符").font(.title2.monospacedDigit())
                }
                Text("runtime \(session.version) · source \(session.source)").font(.caption).foregroundStyle(.secondary)
                if let issue = session.issue { Text(issue).foregroundStyle(.orange) }
                ForEach(session.blocks) { block in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.title)
                            Text("\(block.role) · \(block.kind)").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(block.characters.formatted()).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                Button("在 Finder 查看证据文件") { NSWorkspace.shared.activateFileViewerSelecting([session.file]) }
                    .buttonStyle(.link)
            }.padding(10)
        }
    }

    private func controls(_ session: SessionHeader) -> some View {
        GroupBox("配置管理") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ControlTarget.allCases) { target in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target.title).font(.headline)
                            Text("\(target.isGlobal ? "用户级" : "项目级") · \(target.table).\(target.key)")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("预览关闭") { model.prepare(target, enabled: false) }
                        Button("预览开启") { model.prepare(target, enabled: true) }
                    }
                }
                Text("推荐插件 block 的独立关闭在 Desktop 中尚未可靠确认。此处 Plugins 是整个功能开关。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(10).disabled(!session.complete)
        }
    }

    private var operationPanel: some View {
        GroupBox("修改记录与验证") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(model.operations.prefix(10)) { operation in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(operation.target.title) → \(operation.enabled ? "开启" : "关闭")").font(.headline)
                            Text(operation.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                            if let result = model.verification[operation.id] {
                                Text(result.message).font(.callout)
                                    .foregroundStyle(result.matched == true ? .green : .secondary)
                                if let id = result.sessionID { Text("证据任务：\(id)").font(.caption2.monospaced()).textSelection(.enabled) }
                            }
                        }
                        Spacer()
                        if !operation.restored { Button("撤销") { undoCandidate = operation } }
                    }
                }
            }.padding(10)
        }
    }

    private func previewPanel(_ preview: ConfigPreview) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("预览：\(preview.target.title)").font(.title2.bold())
            Text(preview.target.consequence)
            Text(preview.file.path).font(.caption.monospaced()).textSelection(.enabled)
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("[\(preview.target.table)]")
                    Text("修改前：\(preview.target.key) = \(preview.before.map(String.init) ?? "未设置")")
                    Text("修改后：\(preview.target.key) = \(String(preview.enabled))")
                }.font(.body.monospaced()).frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            Text("保存后显示待验证。已有会话不会因此删除继承的历史；请新建任务验证。")
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { model.preview = nil }.keyboardShortcut(.cancelAction)
                Button("保存配置", action: model.applyPreview).buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(width: 540)
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
