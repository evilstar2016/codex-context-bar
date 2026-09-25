import SwiftUI

struct ProjectMenu: View {
    @Bindable var model: AppModel
    var body: some View {
        Menu {
            ForEach(model.recentProjects, id: \.self) { path in
                Button { model.selectProject(URL(fileURLWithPath: path)) } label: {
                    if model.project?.path == path {
                        Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "checkmark")
                    } else { Text(URL(fileURLWithPath: path).lastPathComponent) }
                }
            }
            if !model.recentProjects.isEmpty { Divider() }
            Button(model.language.text("选择其他项目…"), action: model.chooseProject)
        } label: {
            Label(model.project?.lastPathComponent ?? model.language.text("选择项目"), systemImage: "folder")
                .lineLimit(1).truncationMode(.middle)
        }
        .accessibilityLabel(model.language.text("选择项目"))
        .help(model.project?.path ?? model.language.text("选择 Codex 项目目录"))
    }
}

struct InspectorToolbar: ToolbarContent {
    @Bindable var model: AppModel
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { Task { await model.refresh() } } label: {
                if model.refreshing { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }.disabled(model.refreshing || model.project == nil).help(model.language.text("检查新的会话记录")).accessibilityLabel(model.language.text("刷新会话"))
            GlassAppearanceControl()
            Menu {
                Button(model.language.text("简体中文")) { model.language = .chinese }
                Button("English") { model.language = .english }
            } label: { Image(systemName: "globe") }
            .accessibilityLabel(model.language.text("语言"))
            Menu {
                Button(model.language.text("修改记录")) { model.showingHistory = true }
                Button(model.language.text("选择 Codex 数据目录…"), action: model.chooseCodexHome)
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel(model.language.text("更多选项"))
        }
    }
}

struct SessionSelectionBar: View {
    @Bindable var model: AppModel
    var body: some View {
        HStack(spacing: 16) {
            ProjectMenu(model: model).labelStyle(.titleAndIcon).frame(maxWidth: 240, alignment: .leading)
            Divider().frame(height: 20)
            Picker(model.language.text("页面"), selection: $model.showingSavings) {
                Text(model.language.text("收益仪表盘")).tag(true)
                Text(model.language.text("会话检查器")).tag(false)
            }
            .pickerStyle(.segmented).frame(width: 230)
            if !model.showingSavings {
                Divider().frame(height: 20)
                Menu {
                    if model.sessions.isEmpty { Text(model.language.text("暂无会话")) }
                    ForEach(model.sessions) { session in
                        Button { model.selectedID = session.id } label: {
                            Text("\(session.id == model.selected?.id ? "✓ " : "")\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(session.id.suffix(8)) · \(model.language.text(session.complete ? "完整" : "不完整"))")
                        }
                    }
                } label: {
                    Label(model.selected.map { "\($0.date.formatted(date: .abbreviated, time: .shortened)) · \(model.language.text($0.complete ? "完整" : "不完整"))" } ?? model.language.text("选择会话"), systemImage: "calendar")
                }.disabled(model.sessions.isEmpty).labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
            Text(model.showingSavings ? model.savings.map { String(format: model.language.text("%d 个完整会话"), $0.all30.sessionCount) } ?? model.language.text("等待扫描")
                : String(format: model.language.text("%d 个会话"), model.sessions.count))
                .font(.caption).foregroundStyle(InspectorTheme.secondary)
        }
        .menuStyle(.borderlessButton)
        .tint(InspectorTheme.text)
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(.white.opacity(0.035))
    }
}
