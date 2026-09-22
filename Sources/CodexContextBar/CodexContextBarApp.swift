import AppKit
import ContextCore
import SwiftUI

@main
struct CodexContextBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Context Bar", systemImage: "text.bubble") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Context Bar", id: "dashboard") {
            Dashboard(model: model)
        }
        .defaultSize(width: 1048, height: 786)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
    }
}

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Context Bar").font(.system(size: 22, weight: .medium)).padding(.bottom, 6)
            ProjectMenu(model: model)
                .menuStyle(.borderlessButton).font(.system(size: 14))
                .foregroundStyle(InspectorTheme.secondary).tint(InspectorTheme.secondary)
            InspectorDivider().padding(.top, 20).padding(.bottom, 16)
            Text(model.menuHeadline).font(.system(size: 17, weight: .semibold)).padding(.bottom, 18)
            if model.project != nil {
                VStack(spacing: 14) {
                    ForEach(ControlTarget.allCases) { target in
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill").font(.system(size: 8)).foregroundStyle(color(for: target))
                            Text(target == .skillCatalog ? "技能目录" : target == .plugins ? "Plugins" : "记忆说明")
                            Spacer()
                            Text(status(for: target)).foregroundStyle(InspectorTheme.secondary)
                        }.font(.system(size: 14))
                    }
                }.padding(.bottom, 32)
            } else {
                Text("观察会话头与配置变化，数据仅在本机处理。")
                    .font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary).lineSpacing(4).padding(.bottom, 24)
            }
            Button("打开检查器") {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }.buttonStyle(InspectorButtonStyle(prominent: true))
            HStack(spacing: 8) {
                Text(model.lastRefresh.map { "本地读取 · \($0.formatted(date: .omitted, time: .shortened)) 更新" } ?? "本地读取 · 每分钟检查一次")
                    .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
                Spacer(minLength: 0)
                GlassAppearanceControl()
                Menu {
                    Button("刷新") { Task { await model.refresh() } }
                        .disabled(model.refreshing || model.project == nil)
                    Button("选择 Codex 数据目录…", action: model.chooseCodexHome)
                    Button("恢复默认数据目录", action: model.restoreDefaultCodexHome)
                    Button("退出 Context Bar") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis").font(.system(size: 12)) }
                .menuStyle(.borderlessButton).frame(width: 18).accessibilityLabel("更多选项")
            }.padding(.top, 18)
            if let error = model.error {
                Button {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("读取遇到问题 · 查看详情", systemImage: "exclamationmark.circle")
                        .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
                }.buttonStyle(.plain).help(error).padding(.top, 12)
            }
        }
        .padding(22).frame(width: 316)
        .background { GlassBackground() }
        .foregroundStyle(InspectorTheme.text)

        .tint(InspectorTheme.teal)
    }

    private func status(for target: ControlTarget) -> String {
        switch model.result(for: target)?.state {
        case .waiting: return "待验证"
        case .mismatch, .configChanged: return "需检查"
        case .observed: return "符合预期"
        case .restored: return "已撤销"
        case nil:
            guard let session = model.selected, session.complete else { return "未知" }
            return session.contains(target) ? "存在" : "未观察到"
        }
    }

    private func color(for target: ControlTarget) -> Color {
        switch model.result(for: target)?.state {
        case .waiting, .mismatch, .configChanged: return InspectorTheme.amber
        case .observed: return InspectorTheme.observed
        default: return model.selected?.complete == true ? InspectorTheme.observed : InspectorTheme.secondary
        }
    }
}
