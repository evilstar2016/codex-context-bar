import AppKit
import ContextCore
import Foundation
import Observation

enum SavingsScope { case project, all }

@MainActor @Observable
final class AppModel {
    var language = AppLanguage.chinese {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }
    var project: URL?
    var codexHome: URL
    var sessions: [SessionHeader] = []
    var savings: SavingsSummary?
    var actualSavings: SavingsSummary?
    var pricingMode = SavingsPricingMode.maximum
    var displayedSavings: SavingsSummary? { pricingMode == .maximum ? savings : actualSavings }

    func togglePricingMode() { pricingMode = pricingMode == .maximum ? .actual : .maximum }
    var showingSavings = true
    var savingsScope = SavingsScope.project
    var savingsDays = 30
    var optimizationTarget: ControlTarget? = .skillCatalog
    var activeSavings: SavingsSnapshot? {
        guard let summary = displayedSavings else { return nil }
        if savingsScope == .all { return savingsDays == 7 ? summary.all7 : summary.all30 }
        return savingsDays == 7 ? summary.current7 : summary.current30
    }
    var menuActionTitle: String {
        if attentionCount > 0 { return "查看需检查项" }
        return pendingCount > 0 ? "继续验证" : "查看项目概览"
    }

    func openWorkbench() {
        showingSavings = true
        savingsScope = .project
        let attention = latestOperations.first { [.mismatch, .configChanged].contains(verification[$0.id]?.state) }
        let pending = latestOperations.first { verification[$0.id]?.state == .waiting }
        if let operation = attention ?? pending { optimizationTarget = operation.target }
    }

    func showEvidence(_ target: ControlTarget) {
        selectedKind = InspectorItem.primary.first { $0.target == target }?.id ?? selectedKind
        showingSavings = false
    }

    func previewOptimization(_ target: ControlTarget) {
        guard savingsScope == .project, configProblems[target] == nil else { return }
        optimizationTarget = target
        selectedKind = InspectorItem.primary.first { $0.target == target }?.id ?? selectedKind
        selectUsableSession()
        guard selected?.complete == true else { return }
        prepare(target, enabled: configuredValues[target] == false)
    }

    func optimizationStatus(_ target: ControlTarget) -> String {
        switch result(for: target)?.state {
        case .waiting: return "已保存，等待新任务验证"
        case .observed: return "新任务已验证"
        case .mismatch: return "新任务观测不符"
        case .configChanged: return "配置已变化"
        case .restored: return "已撤销 · 待新观测"
        case nil: return configuredValues[target] == false ? "已保存关闭 · 尚未验证" : "尚未调整"
        }
    }
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

    var preferredSession: SessionHeader? { sessions.first(where: \.complete) ?? sessions.first(where: { !$0.blocks.isEmpty }) ?? sessions.first }
    func selectUsableSession() { selectedID = preferredSession?.id }
    var selected: SessionHeader? { sessions.first { $0.id == selectedID } ?? preferredSession }
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
        if project == nil { return language.text("选择一个项目") }
        if attentionCount > 0 { return String(format: language.text("%d 项需要检查"), attentionCount) }
        if pendingCount > 0 { return String(format: language.text("%d 项待验证"), pendingCount) }
        if selected == nil { return language.text("等待会话记录") }
        return language.text(selected?.complete == true ? "最近会话已读取" : "会话证据不足")
    }
    func operation(for target: ControlTarget?) -> ConfigOperation? {
        guard let target else { return nil }
        return latestOperations.first { $0.target == target }
    }
    func result(for target: ControlTarget?) -> Verification? {
        operation(for: target).flatMap { verification[$0.id] }
    }
    func configurationLabel(for target: ControlTarget?) -> String {
        guard let target else { return language.text("仅观察") }
        if configProblems[target] != nil { return language.text("无法读取") }
        guard let value = configuredValues[target] else { return language.text("未设置") }
        return language.text(value ? "已保存开启" : "已保存关闭")
    }
    var store: OperationStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return OperationStore(directory: operationDirectory ?? support.appendingPathComponent("CodexContextBar/operations"), codexHome: codexHome)
    }

    init(defaults: UserDefaults = .standard, startsMonitoring: Bool = true, operationDirectory: URL? = nil) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .chinese
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
        panel.title = language.text("选择 Codex 项目目录")
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
        sessions = []; savings = nil; actualSavings = nil; selectedID = nil; operations = []; verification = [:]; preview = nil
        selectedKind = InspectorItem.primary[0].id
        savingsScope = .project; optimizationTarget = .skillCatalog
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
        panel.title = language.text("选择 Codex 数据目录（包含 sessions 和 config.toml）")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.showsHiddenFiles = true
        panel.directoryURL = codexHome
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            do { try setCodexHome(url); Task { await refresh() } }
            catch { self.error = error.localizedDescription }
        }
    }

    func setCodexHome(_ url: URL) throws {
        let normalized = url.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized.appendingPathComponent("sessions").path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ContextError.message("此目录不包含 sessions 文件夹。请选择 Codex 数据目录（通常为 ~/.codex），不是项目目录。当前读取来源未更改。")
        }
        codexHome = normalized
        defaults.set(codexHome.path, forKey: "codexHome")
        clearProjectState()
    }

    func restoreDefaultCodexHome() {
        do {
            try setCodexHome(URL(fileURLWithPath: ProcessInfo.processInfo.environment["CODEX_HOME"] ?? NSHomeDirectory() + "/.codex"))
            Task { await refresh() }
        } catch { self.error = error.localizedDescription }
    }

    func refresh() async {
        guard !isDesignPreview, !refreshing, let project else { return }
        let home = codexHome
        refreshing = true
        error = nil
        defer { refreshing = false }
        do {
            let now = Date()
            let scan = try await repository.scan(codexHome: home, project: project, now: now)
            guard self.project == project, codexHome == home else {
                Task { await self.refresh() }
                return
            }
            loadConfiguration()
            sessions = scan.sessions
            savings = SavingsSummary(sessions: scan.recentSessions, project: project, now: now)
            actualSavings = SavingsSummary(sessions: scan.recentSessions, project: project, now: now, pricingMode: .actual)
            warning = scan.warning
            if !sessions.contains(where: { $0.id == selectedID }) { selectUsableSession() }
            operations = try store.operations(project: project)
            verification = try Dictionary(uniqueKeysWithValues: operations.map {
                ($0.id, try store.verify($0, project: project, sessions: sessions))
            })
            lastRefresh = now
        } catch { self.error = error.localizedDescription }
    }

    func prepare(_ target: ControlTarget, enabled: Bool) {
        guard !isDesignPreview, let project, let selected else { return }
        do { preview = try store.preview(project: project, baseline: selected, target: target, enabled: enabled) }
        catch { self.error = error.localizedDescription }
    }

    func guideToDisable(_ target: ControlTarget) {
        showingSavings = true
        guard configuredValues[target] != false else { optimizationTarget = target; return }
        previewOptimization(target)
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
