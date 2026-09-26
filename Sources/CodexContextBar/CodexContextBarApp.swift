import AppKit
import ContextCore
import SwiftUI

@main
struct CodexContextBarApp: App {
    @State private var model = AppModel()
    @AppStorage("appTheme") private var theme = AppTheme.system
    private static let menuBarIcon: NSImage = {
        let image = NSImage(contentsOf: Bundle.module.url(forResource: "MenuBarIcon", withExtension: "pdf")!)!
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model).environment(\.locale, model.language.locale).environment(\.appLanguage, model.language)
                .preferredColorScheme(theme.colorScheme)
        } label: {
            Image(nsImage: Self.menuBarIcon)
                .accessibilityLabel("Context Bar")
        }
        .menuBarExtraStyle(.window)

        Window("Context Bar", id: "dashboard") {
            Dashboard(model: model).environment(\.locale, model.language.locale).environment(\.appLanguage, model.language)
                .preferredColorScheme(theme.colorScheme)
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
                            Text(model.language.text(target == .skillCatalog ? "技能目录" : target == .plugins ? "Plugins" : "记忆说明"))
                            Spacer()
                            Text(status(for: target)).foregroundStyle(InspectorTheme.secondary)
                        }.font(.system(size: 14))
                    }
                }.padding(.bottom, 32)
            } else {
                Text(model.language.text("观察会话头与配置变化，数据仅在本机处理。"))
                    .font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary).lineSpacing(4).padding(.bottom, 24)
            }
            Button(model.language.text(model.menuActionTitle)) {
                model.openWorkbench()
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }.buttonStyle(InspectorButtonStyle(prominent: true))
            HStack(spacing: 8) {
                Text(model.lastRefresh.map { String(format: model.language.text("本地读取 · %@ 更新"), $0.formatted(date: .omitted, time: .shortened)) }
                    ?? model.language.text("本地读取 · 每分钟检查一次"))
                    .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
                Spacer(minLength: 0)
                GlassAppearanceControl()
                Menu {
                    Button(model.language.text("简体中文")) { model.language = .chinese }
                    Button("English") { model.language = .english }
                } label: { Image(systemName: "globe") }
                .menuStyle(.borderlessButton).frame(width: 18).accessibilityLabel(model.language.text("语言"))
                Menu {
                    Button(model.language.text("刷新")) { Task { await model.refresh() } }
                        .disabled(model.refreshing || model.project == nil)
                    Button(model.language.text("选择 Codex 数据目录…"), action: model.chooseCodexHome)
                    Button(model.language.text("恢复默认数据目录"), action: model.restoreDefaultCodexHome)
                    Button(model.language.text("退出 Context Bar")) { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis").font(.system(size: 12)) }
                .menuStyle(.borderlessButton).frame(width: 18).accessibilityLabel(model.language.text("更多选项"))
            }.padding(.top, 18)
            if let error = model.error {
                Button {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label(model.language.text("读取遇到问题 · 查看详情"), systemImage: "exclamationmark.circle")
                        .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
                }.buttonStyle(.plain).help(model.language.text(error)).padding(.top, 12)
            }
        }
        .padding(22).frame(width: 316)
        .background { GlassBackground() }
        .foregroundStyle(InspectorTheme.text)

        .tint(InspectorTheme.teal)
    }

    private func status(for target: ControlTarget) -> String {
        switch model.result(for: target)?.state {
        case .waiting: return model.language.text("待验证")
        case .mismatch, .configChanged: return model.language.text("需检查")
        case .observed: return model.language.text("符合预期")
        case .restored: return model.language.text("已撤销")
        case nil:
            guard let session = model.selected, session.complete else { return model.language.text("未知") }
            return model.language.text(session.contains(target) ? "存在" : "未观察到")
        }
    }

    private func color(for target: ControlTarget) -> Color {
        switch model.result(for: target)?.state {
        case .waiting, .mismatch, .configChanged: return InspectorTheme.amber
        case .observed: return InspectorTheme.observed
        default: return InspectorTheme.secondary
        }
    }
}
