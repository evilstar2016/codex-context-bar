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
    var operations: [ConfigOperation] = []
    var verification: [UUID: Verification] = [:]
    var preview: ConfigPreview?
    var error: String?
    var warning: String?
    var refreshing = false
    var lastRefresh: Date?
    private let repository = SessionRepository()
    private let defaults = UserDefaults.standard

    var selected: SessionHeader? { sessions.first { $0.id == selectedID } ?? sessions.first }
    var store: OperationStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return OperationStore(directory: support.appendingPathComponent("CodexContextBar/operations"), codexHome: codexHome)
    }

    init() {
        let savedHome = defaults.string(forKey: "codexHome")
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
        codexHome = URL(fileURLWithPath: savedHome ?? NSHomeDirectory() + "/.codex")
            .standardizedFileURL.resolvingSymlinksInPath()
        if let savedProject = defaults.string(forKey: "project") { project = URL(fileURLWithPath: savedProject) }
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
            project = url.standardizedFileURL.resolvingSymlinksInPath()
            defaults.set(project?.path, forKey: "project")
            sessions = []; selectedID = nil; operations = []; verification = [:]; preview = nil
            Task { await refresh() }
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
            sessions = []; selectedID = nil; preview = nil
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard !refreshing, let project else { return }
        let home = codexHome
        refreshing = true
        defer { refreshing = false }
        do {
            let scan = try await repository.scan(codexHome: home, project: project)
            guard self.project == project, codexHome == home else {
                Task { await self.refresh() }
                return
            }
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
        guard let project, let selected else { return }
        do { preview = try store.preview(project: project, baseline: selected, target: target, enabled: enabled) }
        catch { self.error = error.localizedDescription }
    }

    func applyPreview() {
        guard let preview, let project else { return }
        do {
            _ = try store.apply(preview, project: project)
            self.preview = nil
            Task { await refresh() }
        } catch { self.preview = nil; self.error = error.localizedDescription }
    }

    func undo(_ operation: ConfigOperation) {
        guard let project else { return }
        do { try store.undo(operation, project: project); Task { await refresh() } }
        catch { self.error = error.localizedDescription }
    }
}
