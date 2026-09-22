import AppKit
import ContextCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    var project: URL?
    var codexHome: URL
    var sessions: [SessionHeader] = []
    var selectedID: String?
    var selectedKind = InspectorItem.primary[0].id
    var recentProjects: [String] = []
    var configuredValues: [ControlTarget: Bool] = [:]
    var configProblems: [ControlTarget: String] = [:]
    var showingHistory = false
    var isDesignPreview = false
    var operations: [ConfigOperation] = []
    var verification: [UUID: Verification] = [:]
    var preview: ConfigPreview?
    var error: String?
    var warning: String?
    var refreshing = false
    var lastRefresh: Date?
    private let repository = SessionRepository()
    private let defaults: UserDefaults
    private let operationDirectory: URL?

    var selected: SessionHeader? { sessions.first { $0.id == selectedID } ?? sessions.first }
    var selectedItem: InspectorItem {
        InspectorItem.items(in: selected).first { $0.id == selectedKind } ?? InspectorItem.primary[0]
    }
    var latestOperations: [ConfigOperation] {
        ControlTarget.allCases.compactMap { target in operations.first { $0.target == target } }
    }
    var pendingCount: Int { latestOperations.filter { verification[$0.id]?.state == .waiting }.count }
    var attentionCount: Int {
        latestOperations.filter { verification[$0.id]?.state == .mismatch || verification[$0.id]?.state == .configChanged }.count
    }
    var menuHeadline: String {
        if project == nil { return "选择一个项目" }
        if attentionCount > 0 { return "\(attentionCount) 项需要检查" }
        if pendingCount > 0 { return "\(pendingCount) 项待验证" }
        if selected == nil { return "等待会话记录" }
        return selected?.complete == true ? "最近会话已读取" : "会话证据不足"
    }
    func operation(for target: ControlTarget?) -> ConfigOperation? {
        guard let target else { return nil }
        return latestOperations.first { $0.target == target }
    }
    func result(for target: ControlTarget?) -> Verification? {
        operation(for: target).flatMap { verification[$0.id] }
    }
    func configurationLabel(for target: ControlTarget?) -> String {
        guard let target else { return "仅观察" }
        if configProblems[target] != nil { return "无法读取" }
        guard let value = configuredValues[target] else { return "未设置" }
        return value ? "已保存开启" : "已保存关闭"
    }
    var store: OperationStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return OperationStore(directory: operationDirectory ?? support.appendingPathComponent("CodexContextBar/operations"), codexHome: codexHome)
    }

    init(defaults: UserDefaults = .standard, startsMonitoring: Bool = true, operationDirectory: URL? = nil) {
        self.defaults = defaults
        self.operationDirectory = operationDirectory
        recentProjects = defaults.stringArray(forKey: "recentProjects") ?? []
        let savedHome = defaults.string(forKey: "codexHome")
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
        codexHome = URL(fileURLWithPath: savedHome ?? NSHomeDirectory() + "/.codex")
            .standardizedFileURL.resolvingSymlinksInPath()
        if let savedProject = defaults.string(forKey: "project") { project = URL(fileURLWithPath: savedProject) }
        guard startsMonitoring else { return }
        Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex 项目目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            selectProject(url)
        }
    }

    func selectProject(_ url: URL) {
        project = url.standardizedFileURL.resolvingSymlinksInPath()
        defaults.set(project?.path, forKey: "project")
        if let path = project?.path {
            recentProjects = [path] + recentProjects.filter { $0 != path }
            recentProjects = Array(recentProjects.prefix(6))
            defaults.set(recentProjects, forKey: "recentProjects")
        }
        clearProjectState()
        Task { await refresh() }
    }

    private func clearProjectState() {
        sessions = []; selectedID = nil; operations = []; verification = [:]; preview = nil
        selectedKind = InspectorItem.primary[0].id
        configuredValues = [:]; configProblems = [:]; warning = nil; lastRefresh = nil
    }

    func loadConfiguration() {
        configuredValues = [:]; configProblems = [:]
        guard let project else { return }
        for target in ControlTarget.allCases {
            let file = store.configURL(project: project, target: target)
            do {
                guard FileManager.default.fileExists(atPath: file.path) else { continue }
                let text = try String(contentsOf: file, encoding: .utf8)
                configuredValues[target] = try ConfigEditor.value(in: text, target: target)
            } catch { configProblems[target] = error.localizedDescription }
        }
    }

    func chooseCodexHome() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex 数据目录（包含 sessions 和 config.toml）"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.showsHiddenFiles = true
        panel.directoryURL = codexHome
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            codexHome = url.standardizedFileURL.resolvingSymlinksInPath()
            defaults.set(codexHome.path, forKey: "codexHome")
            clearProjectState()
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard !isDesignPreview, !refreshing, let project else { return }
        let home = codexHome
        refreshing = true
        defer { refreshing = false }
        do {
            let scan = try await repository.scan(codexHome: home, project: project)
            guard self.project == project, codexHome == home else {
                Task { await self.refresh() }
                return
            }
            loadConfiguration()
            sessions = scan.sessions
            warning = scan.warning
            if !sessions.contains(where: { $0.id == selectedID }) { selectedID = sessions.first?.id }
            operations = try store.operations(project: project)
            verification = try Dictionary(uniqueKeysWithValues: operations.map {
                ($0.id, try store.verify($0, project: project, sessions: sessions))
            })
            lastRefresh = Date()
        } catch { self.error = error.localizedDescription }
    }

    func prepare(_ target: ControlTarget, enabled: Bool) {
        guard !isDesignPreview, let project, let selected else { return }
        do { preview = try store.preview(project: project, baseline: selected, target: target, enabled: enabled) }
        catch { self.error = error.localizedDescription }
    }

    func applyPreview() {
        guard !isDesignPreview, let preview, let project else { return }
        do {
            _ = try store.apply(preview, project: project)
            self.preview = nil
            Task { await refresh() }
        } catch { self.preview = nil; self.error = error.localizedDescription }
    }

    func undo(_ operation: ConfigOperation) {
        guard !isDesignPreview, let project else { return }
        do { try store.undo(operation, project: project); Task { await refresh() } }
        catch { self.error = error.localizedDescription }
    }
}
