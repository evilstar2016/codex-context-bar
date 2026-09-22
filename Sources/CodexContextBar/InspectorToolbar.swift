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
            Button("选择其他项目…", action: model.chooseProject)
        } label: {
            Label(model.project?.lastPathComponent ?? "选择项目", systemImage: "folder")
                .lineLimit(1).truncationMode(.middle)
        }
        .accessibilityLabel("选择项目")
        .help(model.project?.path ?? "选择 Codex 项目目录")
    }
}

struct InspectorToolbar: ToolbarContent {
    @Bindable var model: AppModel
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Text("Context Bar").font(.system(size: 17, weight: .medium))
        }
        ToolbarItemGroup(placement: .primaryAction) {
            ProjectMenu(model: model).frame(maxWidth: 200)
            Menu {
                if model.sessions.isEmpty { Text("暂无会话") }
                ForEach(model.sessions) { session in
                    Button {
                        model.selectedID = session.id
                    } label: {
                        Text("\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(session.id.prefix(8)) · \(session.complete ? "完整" : "不完整")")
                    }
                }
            } label: {
                Label(model.selected?.date.formatted(date: .abbreviated, time: .shortened) ?? "选择会话", systemImage: "calendar")
            }.disabled(model.sessions.isEmpty).accessibilityLabel("选择观察会话")
            Button { Task { await model.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
            }.disabled(model.refreshing || model.project == nil).help("检查新的会话记录").accessibilityLabel("刷新会话")
            Menu {
                Button("修改记录") { model.showingHistory = true }
                Button("选择 Codex 数据目录…", action: model.chooseCodexHome)
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("更多选项")
        }
    }
}
