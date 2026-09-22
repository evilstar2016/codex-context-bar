import AppKit
import ContextCore
import SwiftUI

@main
struct CodexContextBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Codex Context Bar", systemImage: "text.badge.checkmark") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Codex Context Bar", id: "dashboard") {
            Dashboard(model: model)
        }
        .defaultSize(width: 820, height: 720)
        .windowResizability(.contentMinSize)
    }
}

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Codex Context Bar", systemImage: "text.badge.checkmark")
                .font(.headline)
            Text(model.project?.lastPathComponent ?? "选择项目以开始")
                .font(.subheadline).foregroundStyle(.secondary)
            if let session = model.selected {
                HStack {
                    Image(systemName: session.complete ? "checkmark.seal" : "questionmark.circle")
                        .foregroundStyle(session.complete ? .green : .orange)
                    Text(session.complete ? "完整初始会话头" : "证据不足")
                    Spacer()
                    Text("\(session.characters.formatted()) 字符").monospacedDigit()
                }
                ForEach(ControlTarget.allCases) { target in
                    HStack {
                        Text(target.title)
                        Spacer()
                        Text(!session.complete ? "未知" : session.contains(target) ? "存在" : "未观察到")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("历史观测 · \(session.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("读取本机日志，观察会话头与配置是否一致。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let operation = model.operations.first, let result = model.verification[operation.id] {
                Text(result.message).font(.caption).foregroundStyle(.secondary)
            }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).lineLimit(3) }
            Divider()
            HStack {
                Button("打开详情") { openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
                    .buttonStyle(.borderedProminent)
                Button("选择项目") { model.chooseProject() }
                Spacer()
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(model.refreshing).help("刷新")
            }
            HStack {
                Text("本地分析 · 每分钟检查一次").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.caption)
            }
        }
        .padding(20).frame(width: 370)
    }
}
