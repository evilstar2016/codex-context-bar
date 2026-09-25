import AppKit
import ContextCore
import SwiftUI

struct Dashboard: View {
    @Bindable var model: AppModel
    @State private var expandedOthers = true
    @State private var showingEvidence = false
    @State private var undoCandidate: ConfigOperation?

    var body: some View {
        VStack(spacing: 0) {
            SessionSelectionBar(model: model)
            InspectorDivider()
            if model.showingSavings {
                SavingsDashboard(model: model)
            } else {
                GeometryReader { geometry in
                    HSplitView {
                        overview
                            .frame(minWidth: 470, idealWidth: 628, maxWidth: .infinity, maxHeight: .infinity)
                        inspector(compact: geometry.size.height < 720)
                            .frame(minWidth: 340, idealWidth: 420, maxWidth: 420, maxHeight: .infinity)
                    }
                }
            }
        }
        .background { GlassBackground() }
        .foregroundStyle(InspectorTheme.text)

        .tint(InspectorTheme.teal)
        .frame(minWidth: 880, minHeight: 640)
        .toolbar { InspectorToolbar(model: model) }
        .sheet(item: $model.preview) { preview in ConfigPreviewSheet(model: model, preview: preview) }
        .sheet(isPresented: $model.showingHistory) { OperationHistorySheet(model: model) }
        .alert(model.language.text("无法完成操作"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.language.text("知道了"), role: .cancel) { model.error = nil }
        } message: { Text(model.language.text(model.error ?? "")) }
        .alert(model.language.text("撤销这次配置修改？"), isPresented: Binding(get: { undoCandidate != nil }, set: { if !$0 { undoCandidate = nil } })) {
            Button(model.language.text("取消"), role: .cancel) { undoCandidate = nil }
            Button(model.language.text("撤销")) { if let operation = undoCandidate { model.undo(operation) }; undoCandidate = nil }
        } message: { Text(model.language.text("只恢复本次目标键，保留其他修改。恢复效果仍需新会话观察。")) }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.language.text(model.isDesignPreview ? "示例会话" : "历史会话"))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                Text(model.language.text(model.selected?.id == model.sessions.first?.id ? "最近会话的初始上下文" : "所选会话的初始上下文"))
                    .font(.system(size: 30, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(sessionSubtitle).font(.system(size: 15)).foregroundStyle(InspectorTheme.secondary)
            }.padding(.bottom, 20)
            if let session = model.selected, !session.complete {
                VStack(alignment: .leading, spacing: 10) {
                    Label(model.language.text("当前记录不是完整会话头"), systemImage: "info.circle").font(.headline)
                    Text(model.language.text(session.issue ?? "无法判断未出现的内容是否被关闭。"))
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                    if let usable = model.preferredSession, usable.complete {
                        Button(String(format: model.language.text("查看最近完整会话 · %@"), usable.date.formatted(date: .abbreviated, time: .shortened))) { model.selectUsableSession() }
                    }
                }.foregroundStyle(InspectorTheme.amber).padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(InspectorTheme.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 16)
            }

            if model.project == nil {
                emptyState(title: "先选择一个项目", description: "读取本机 Codex 会话记录，观察初始上下文与配置是否一致。", symbol: "folder") {
                    model.chooseProject()
                }
            } else if model.selected == nil {
                emptyState(title: model.refreshing ? "正在读取会话记录" : "尚未找到会话记录",
                    description: "在 Codex Desktop 使用这个项目目录新建任务，再检查新的会话头。", symbol: "doc.text.magnifyingglass") {
                    Task { await model.refresh() }
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        HStack {
                            Text(model.language.text("内容")).frame(maxWidth: .infinity, alignment: .leading)
                            Text(model.language.text("观测")).frame(width: 84, alignment: .leading)
                            Text("Token").frame(width: 80, alignment: .trailing)
                        }
                        .font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
                        .padding(.horizontal, 20).frame(height: 38)
                        InspectorDivider()
                        ForEach(InspectorItem.primary) { item in itemRow(item) }
                        if !otherItems.isEmpty {
                            Button {
                                expandedOthers.toggle()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: expandedOthers ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 13)).frame(width: 20)
                                    Text(model.language.text("其他会话说明")).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format: model.language.text("%d 项"), otherItems.count)).frame(width: 84, alignment: .leading)
                                    Text(otherItems.compactMap { $0.tokens(in: model.selected) }.reduce(0, +).formatted()).monospacedDigit().frame(width: 80, alignment: .trailing)
                                }
                                .font(.system(size: 15)).foregroundStyle(InspectorTheme.secondary)
                                .padding(.horizontal, 20).frame(minHeight: 62).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(model.language.text(expandedOthers ? "收起其他会话说明" : "展开其他会话说明"))
                            if expandedOthers { ForEach(otherItems) { item in itemRow(item) } }
                        }
                    }
                    .background(.white.opacity(0.025))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(InspectorTheme.line))


                }
                .scrollIndicators(.visible)
            }
            if let warning = model.warning {
                inlineNotice(model.language.text(warning))
                if model.sessions.isEmpty {
                    Button(model.language.text("恢复默认数据目录"), action: model.restoreDefaultCodexHome).padding(.top, 8)
                }
            }
            Text(String(format: model.language.text("读取来源：%@"), model.codexHome.path))
                .font(.caption).foregroundStyle(InspectorTheme.secondary)
                .textSelection(.enabled).lineLimit(2).truncationMode(.middle).padding(.top, 12)
            Spacer(minLength: 16)
            HStack {
                Text(totalLabel)
                Spacer()
                if model.refreshing { ProgressView().controlSize(.small).accessibilityLabel(model.language.text("正在检查会话")) }
            }
            .font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
        }
        .padding(.horizontal, 30).padding(.top, 28).padding(.bottom, 24)
    }

    private func itemRow(_ item: InspectorItem) -> some View {
        VStack(spacing: 0) {
            Button {
                model.selectedKind = item.id
                showingEvidence = false
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: item.symbol).font(.system(size: 20, weight: .light)).frame(width: 20)
                    Text(model.language.text(item.title)).fontWeight(model.selectedKind == item.id ? .medium : .regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(model.language.text(item.observation(in: model.selected))).frame(width: 84, alignment: .leading)
                    Text(item.tokens(in: model.selected)?.formatted() ?? "—")
                        .monospacedDigit().frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 20).frame(minHeight: 56)
                .background(model.selectedKind == item.id ? InspectorTheme.selection : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(model.selectedKind == item.id ? [.isSelected] : [])
            InspectorDivider()
        }
    }

    private func inspector(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 20) {
                        Image(systemName: model.selectedItem.symbol)
                            .font(.system(size: 44, weight: .light)).foregroundStyle(InspectorTheme.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.language.text(model.selectedItem.title)).font(.system(size: 25, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(model.language.text(model.selectedItem.scope)).font(.system(size: 14)).foregroundStyle(InspectorTheme.secondary)
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.top, compact ? 34 : 66).padding(.bottom, compact ? 30 : 46)
                    InspectorDivider()
                    VStack(alignment: .leading, spacing: compact ? 18 : 22) {
                        detailRow("配置状态", value: model.configurationLabel(for: model.selectedItem.target))
                        detailRow("所选观测", value: model.language.text(model.selectedItem.observation(in: model.selected)))
                        HStack(alignment: .top, spacing: 18) {
                            Text(model.language.text("当前状态")).foregroundStyle(InspectorTheme.secondary).frame(width: 78, alignment: .leading)
                            StatusLabel(text: model.language.text(statusText), color: statusColor).fixedSize(horizontal: false, vertical: true)
                        }.font(.system(size: 15))
                    }.padding(.vertical, compact ? 22 : 34)
                    actions.padding(.top, compact ? 14 : 50).padding(.bottom, compact ? 24 : 48)
                    InspectorDivider()
                    evidence.padding(.vertical, compact ? 22 : 40)
                }
            }.scrollIndicators(.automatic)
            InspectorDivider()
            Text(model.language.text(model.selectedItem.consequence))
                .font(.system(size: 12)).lineSpacing(3).foregroundStyle(InspectorTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18).padding(.bottom, compact ? 20 : 36)
        }.padding(.horizontal, 28)
    }

    @ViewBuilder private var actions: some View {
        if let target = model.selectedItem.target {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.language.text(actionHelp)).font(.system(size: 14)).lineSpacing(4).foregroundStyle(InspectorTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 8)
                if let result = model.result(for: target), result.state == .waiting || result.state == .mismatch || result.state == .configChanged {
                    Button(model.language.text(model.refreshing ? "正在检查…" : "检查新任务")) { Task { await model.refresh() } }
                        .buttonStyle(InspectorButtonStyle(prominent: true)).disabled(model.refreshing)
                } else {
                    Button(model.language.text(model.configuredValues[target] == false ? "预览开启" : "预览关闭")) {
                        model.prepare(target, enabled: model.configuredValues[target] == false)
                    }
                    .buttonStyle(InspectorButtonStyle(prominent: true))
                    .disabled(model.selected?.complete != true || model.configProblems[target] != nil)
                }
                if let operation = model.operation(for: target), !operation.restored {
                    Button(model.language.text("撤销此次修改")) { undoCandidate = operation }
                        .buttonStyle(InspectorButtonStyle())
                }
                if let result = model.result(for: target), result.state == .configChanged {
                    Button(model.language.text("重新预览配置")) { model.prepare(target, enabled: model.configuredValues[target] == false) }
                        .buttonStyle(.link).font(.system(size: 13))
                        .disabled(model.selected?.complete != true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.language.text(model.selectedItem.id == "plugins.recommendations" ? "此项暂不提供独立关闭。可在插件说明中管理整个 Plugins 功能。" : "此项仅供观察，可展开下方的配置与证据查看来源。"))
                    .font(.system(size: 14)).lineSpacing(4).foregroundStyle(InspectorTheme.secondary)
                if model.selectedItem.id == "plugins.recommendations" {
                    Button(model.language.text("查看 Plugins 功能")) { model.selectedKind = "plugins.usage_instructions" }
                        .buttonStyle(InspectorButtonStyle())
                }
            }
        }
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showingEvidence.toggle() } label: {
                Label(model.language.text("查看配置与证据"), systemImage: showingEvidence ? "chevron.down" : "chevron.right")
                    .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if showingEvidence {
                VStack(alignment: .leading, spacing: 12) {
                    if let session = model.selected {
                        evidenceLine("所选会话", session.id)
                        evidenceLine("Runtime", model.language.text(session.version))
                        evidenceLine("Source", model.language.text(session.source))
                        evidenceLine("Metadata", model.selectedItem.id)
                        Button(model.language.text("在 Finder 查看会话记录")) { NSWorkspace.shared.activateFileViewerSelecting([session.file]) }
                            .buttonStyle(.link)
                    }
                    if let target = model.selectedItem.target, let project = model.project {
                        evidenceLine("写入位置", model.store.configURL(project: project, target: target).path)
                        evidenceLine("配置键", "\(target.table).\(target.key)")
                        if let problem = model.configProblems[target] { Text(model.language.text(problem)).foregroundStyle(InspectorTheme.amber) }
                    }
                    if let result = model.result(for: model.selectedItem.target) {
                        Text(model.language.text(result.message))
                        if let id = result.sessionID { evidenceLine("验证会话", id) }
                    }
                    Text(model.language.text("配置状态仅表示目标文件中的键值；其它配置层与宿主可能覆盖。观测不代表每次完整请求，也不证明唯一因果。"))
                    Text(model.language.text("验证基线：runtime 0.154.0-alpha.6.2。其它版本需重新观察。Token 为估算值，不是账单节省。"))
                }
                .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                .textSelection(.enabled)
            } else {
                Text(model.language.text("显示相关路径、运行时信息、来源和元数据标识符。"))
                    .font(.system(size: 12)).lineSpacing(3).foregroundStyle(InspectorTheme.secondary)
            }
        }
    }

    private func evidenceLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.language.text(title))
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(InspectorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(model.language.text(title)).foregroundStyle(InspectorTheme.secondary).frame(width: 78, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true)
        }.font(.system(size: 15))
    }

    private var statusText: String {
        if let result = model.result(for: model.selectedItem.target) {
            switch result.state {
            case .waiting: return "等待新任务验证"
            case .observed: return "新任务观测符合预期"
            case .mismatch: return "新任务观测不符"
            case .configChanged: return "配置已变化"
            case .restored: return "已撤销 · 待新观测"
            }
        }
        if model.project == nil { return "尚未选择项目" }
        return model.selected?.complete == true ? "已读取历史证据" : "证据不足"
    }
    private var statusColor: Color {
        switch model.result(for: model.selectedItem.target)?.state {
        case .waiting, .mismatch, .configChanged: InspectorTheme.amber
        case .observed: InspectorTheme.observed
        default: InspectorTheme.secondary
        }
    }
    private var actionHelp: String {
        if let target = model.selectedItem.target, let problem = model.configProblems[target] { return problem }
        switch model.result(for: model.selectedItem.target)?.state {
        case .waiting: return "修改后请在同一项目新建任务，再检查会话头。"
        case .observed: return "新的完整会话头符合预期，可在证据中查看对应任务。"
        case .mismatch: return "新任务观测与配置不符，请检查作用范围或其它配置覆盖。"
        case .configChanged: return "目标配置或其它配置层已变化，请重新预览后验证。"
        case .restored: return "目标键已恢复，恢复效果仍需新的完整会话头确认。"
        default: return model.selected?.complete == true ? "先预览作用范围与具体修改，保存后再用新任务验证。" : "请选择完整的初始会话头，再预览配置修改。"
        }
    }
    private var sessionSubtitle: String {
        guard let session = model.selected else { return model.language.text(model.refreshing ? "正在读取所选项目的会话…" : "本地读取 · 配置与实际观测分开展示") }
        return "\(model.language.text(session.complete ? "完整会话头" : "不完整会话头")) · \(session.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))"
    }
    private var totalLabel: String {
        guard let session = model.selected else { return model.language.text("数据仅在本机处理") }
        if !session.complete && session.blocks.isEmpty { return model.language.text("无可用会话头数据 · 不代表 0 Token") }
        return String(format: model.language.text("%@ 约 %@ Token"), model.language.text(session.complete ? "已观测" : "部分观测"), session.tokens.formatted())
    }
    private var otherItems: [InspectorItem] { Array(InspectorItem.items(in: model.selected).dropFirst(4)) }

    private func inlineNotice(_ text: String) -> some View {
        Label(text, systemImage: "info.circle").font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
    }

    private func emptyState(title: String, description: String, symbol: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(InspectorTheme.secondary)
            Text(model.language.text(title)).font(.system(size: 21, weight: .medium))
            Text(model.language.text(description)).font(.system(size: 14)).foregroundStyle(InspectorTheme.secondary).lineSpacing(4)
            Button(model.language.text(model.project == nil ? "选择项目" : "检查会话"), action: action)
                .buttonStyle(InspectorButtonStyle(prominent: true)).frame(maxWidth: 240).disabled(model.refreshing)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 42)
    }
}
