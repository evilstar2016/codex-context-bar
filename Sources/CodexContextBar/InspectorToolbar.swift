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

struct WorkbenchSettings: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.language.text("设置")).font(.headline)
            Picker(model.language.text("语言"), selection: $model.language) {
                Text("简体中文").tag(AppLanguage.chinese)
                Text("English").tag(AppLanguage.english)
            }
            HStack {
                Text(model.language.text("外观与透明度"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                GlassAppearanceControl(showsTitle: true)
            }
            Divider()
            Text(model.language.text("Codex 数据目录")).font(.subheadline)
            Text(model.codexHome.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button(model.language.text("选择 Codex 数据目录…")) { dismiss(); model.chooseCodexHome() }
            Button(model.language.text("恢复默认数据目录")) { dismiss(); model.restoreDefaultCodexHome() }
        }
        .padding(20).frame(width: 300)
        .foregroundStyle(InspectorTheme.text).background { GlassBackground() }
        .environment(\.appLanguage, model.language)
    }

}

struct SessionSelectionBar: View {
    @Bindable var model: AppModel
    @State private var showingSettings = false

    var body: some View {
        HStack(spacing: 14) {
            Button { model.showingSavings = true } label: {
                Label(model.language.text("返回优化"), systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            Divider().frame(height: 18)
            ProjectMenu(model: model).labelStyle(.titleOnly).frame(maxWidth: 160, alignment: .leading)
            Menu {
                if model.sessions.isEmpty { Text(model.language.text("暂无会话")) }
                ForEach(model.sessions) { session in
                    Button { model.selectedID = session.id } label: {
                        Text("\(session.id == model.selected?.id ? "✓ " : "")\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(session.id.suffix(8)) · \(model.language.text(session.complete ? "完整" : "不完整"))")
                    }
                }
            } label: {
                Text(model.selected.map { "\($0.date.formatted(date: .abbreviated, time: .shortened)) · \(model.language.text($0.complete ? "完整" : "不完整"))" } ?? model.language.text("选择会话"))
                    .lineLimit(1)
            }
            .disabled(model.sessions.isEmpty)
            .accessibilityLabel(model.language.text("选择会话"))
            Spacer(minLength: 8)
            Button { Task { await model.refresh() } } label: {
                if model.refreshing { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }
            .disabled(model.refreshing || model.project == nil)
            .help(model.language.text("检查新的会话记录"))
            .accessibilityLabel(model.language.text("刷新会话"))
            Menu {
                Button(model.language.text("修改记录")) { model.showingHistory = true }
                Button(model.language.text("设置")) { showingSettings = true }
            } label: { Image(systemName: "ellipsis") }
            .accessibilityLabel(model.language.text("更多选项"))
            .popover(isPresented: $showingSettings) { WorkbenchSettings(model: model) }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 28).frame(height: 54)
        .background { GlassBackground() }
    }
}
