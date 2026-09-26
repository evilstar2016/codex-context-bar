import AppKit
import ContextCore
import SwiftUI
import Testing
@testable import CodexContextBar

@MainActor
private struct InspectorFixture {
    let root: URL
    let defaults: UserDefaults
    let suite: String
    let model: AppModel

    init(pending: Bool = true) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("inspector-" + UUID().uuidString)
        let project = root.appendingPathComponent("skill-doctor")
        let home = root.appendingPathComponent("codex")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        suite = "context-bar-tests-" + UUID().uuidString
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(project.path, forKey: "project")
        defaults.set(home.path, forKey: "codexHome")
        model = AppModel(defaults: defaults, startsMonitoring: false, operationDirectory: root.appendingPathComponent("operations"))
        let header = try makeHeader(project: project, file: root.appendingPathComponent("synthetic.jsonl"))
        model.sessions = [header]
        model.selectedID = header.id
        model.showingSavings = false
        model.recentProjects = [project.path]
        model.lastRefresh = ISO8601DateFormatter().date(from: "2026-09-22T11:56:00Z")
        model.savings = SavingsSummary(sessions: [header], project: project, now: try #require(model.lastRefresh))
        model.actualSavings = SavingsSummary(sessions: [header], project: project, now: try #require(model.lastRefresh), pricingMode: .actual)
        if pending {
            let preview = try model.store.preview(project: project, baseline: header, target: .skillCatalog, enabled: false)
            let operation = try model.store.apply(preview, project: project)
            model.operations = [operation]
            model.verification[operation.id] = try model.store.verify(operation, project: project, sessions: [header])
        }
        model.loadConfiguration()
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}

private func makeHeader(project: URL, file: URL, kinds: [(String, Int)]? = nil) throws -> SessionHeader {
    let entries = kinds ?? [
        ("host_skills.instructions", 6840), ("memories.instructions", 2360),
        ("plugins.usage_instructions", 1420), ("plugins.recommendations", 2907),
        ("permissions.instructions", 170), ("apps.instructions", 180),
        ("collaboration_mode.instructions", 190), ("environments.environment_context", 200),
    ]
    let records: [[String: Any]] = [
        ["type": "session_meta", "payload": ["id": "design-baseline", "cwd": project.path,
            "timestamp": "2026-09-22T11:42:00Z", "cli_version": "0.154.0-alpha.6.2", "source": "desktop"]],
        ["type": "response_item", "payload": ["role": "developer",
            "content": entries.map { ["text": String(repeating: "示", count: $0.1)] },
            "internal_chat_message_metadata_passthrough": ["content_item_kinds": entries.map(\.0)]]],
        ["type": "response_item", "payload": ["role": "user", "content": [["text": ""]],
            "internal_chat_message_metadata_passthrough": ["content_item_kinds": ["environments.environment_context"]]]],
        ["type": "world_state", "payload": ["full": true]],
        ["type": "turn_context", "payload": ["cwd": project.path, "model": "gpt-5.6-sol", "turn_id": "design-turn"]],
    ]
    let usageRecord: [String: Any] = ["type": "token_usage_record", "payload": [
        "thread_id": "design-baseline", "response_id": "design-response", "turn_id": "design-turn",
        "usage": ["input_tokens": 20000, "cached_input_tokens": 18000, "cache_write_input_tokens": 0,
            "output_tokens": 500, "reasoning_output_tokens": 100, "total_tokens": 20500]]]
    let data = try (records + [usageRecord]).enumerated().reduce(into: Data()) { data, record in
        var object = record.element
        object["ordinal"] = record.offset
        object["timestamp"] = "2026-09-22T11:45:00Z"
        data.append(try JSONSerialization.data(withJSONObject: object)); data.append(10)
    }
    try data.write(to: file)
    var header = try #require(HeaderParser.parse(data, file: file))
    header.responses = try HistoryParser.read(file, header: header).responses
    return header
}

@Test @MainActor func pendingStateIsSeparateFromObservedPresence() throws {
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    let model = fixture.model
    #expect(model.pendingCount == 1)
    #expect(model.attentionCount == 0)
    #expect(model.menuHeadline == "1 项待验证")
    #expect(model.configurationLabel(for: .skillCatalog) == "已保存关闭")
    #expect(model.selectedItem.observation(in: model.selected) == "存在")
    #expect(model.result(for: .skillCatalog)?.state == .waiting)
}

@Test @MainActor func selectionPreservesReadOnlyRecommendationBoundary() throws {
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    fixture.model.selectedKind = "plugins.recommendations"
    #expect(fixture.model.selectedItem.title == "推荐插件")
    #expect(fixture.model.selectedItem.target == nil)
    #expect(fixture.model.selectedItem.tokens(in: fixture.model.selected) == TokenEstimate.count(String(repeating: "示", count: 2907)))
    fixture.model.selectedKind = "plugins.usage_instructions"
    #expect(fixture.model.selectedItem.target == .plugins)
    #expect(fixture.model.selectedItem.scope.contains("所有项目"))
}

@Test @MainActor func absentControlsRemainSelectableAndUnknownIsNotZero() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    var header = try makeHeader(project: try #require(fixture.model.project), file: fixture.root.appendingPathComponent("empty.jsonl"), kinds: [])
    #expect(InspectorItem.items(in: header).count >= 4)
    #expect(InspectorItem.primary[0].tokens(in: header) == 0)
    #expect(InspectorItem.primary[0].observation(in: header) == "未观察到")
    header.complete = false
    #expect(InspectorItem.primary[0].tokens(in: header) == nil)
    #expect(InspectorItem.primary[0].observation(in: header) == "未知")
}

@Test @MainActor func previewChangesNoConfigurationUntilSaved() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    fixture.model.prepare(.memory, enabled: false)
    let preview = try #require(fixture.model.preview)
    #expect(preview.target.isGlobal)
    #expect(!FileManager.default.fileExists(atPath: preview.file.path))
    fixture.model.preview = nil
    #expect(!FileManager.default.fileExists(atPath: preview.file.path))
}

@Test @MainActor func guidedDisableOpensPreviewAndLanguagePersists() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    let model = fixture.model
    model.language = .english
    #expect(model.language.text("自动技能目录") == "Automatic skill catalog")
    #expect(fixture.defaults.string(forKey: "language") == "en")
    model.showingSavings = true
    model.guideToDisable(.memory)
    #expect(model.showingSavings)
    #expect(model.selectedKind == "memories.instructions")
    #expect(model.preview?.target == .memory)
    let project = try #require(model.project)
    let file = model.store.configURL(project: project, target: .memory)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    let reloaded = AppModel(defaults: fixture.defaults, startsMonitoring: false, operationDirectory: fixture.root.appendingPathComponent("other-operations"))
    #expect(reloaded.language == .english)
}

@Test @MainActor func onlyLatestOperationPerTargetCountsAsPending() throws {
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    let model = fixture.model
    let project = try #require(model.project)
    let baseline = try #require(model.selected)
    let preview = try model.store.preview(project: project, baseline: baseline, target: .skillCatalog, enabled: true)
    let second = try model.store.apply(preview, project: project)
    model.operations.insert(second, at: 0)
    model.verification[second.id] = try model.store.verify(second, project: project, sessions: model.sessions)
    #expect(model.latestOperations.count == 1)
    #expect(model.pendingCount == 1)
}

@Test @MainActor func configChangeIsAttentionRatherThanPending() throws {
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    let model = fixture.model
    let project = try #require(model.project)
    let file = model.store.configURL(project: project, target: .skillCatalog)
    try "[skills]\ninclude_instructions = true\n".write(to: file, atomically: true, encoding: .utf8)
    let operation = try #require(model.operations.first)
    model.verification[operation.id] = try model.store.verify(operation, project: project, sessions: model.sessions)
    #expect(model.pendingCount == 0)
    #expect(model.attentionCount == 1)
    #expect(model.menuHeadline == "1 项需要检查")
}

/// Opt-in snapshots render the actual SwiftUI views in isolated, off-screen
/// NSHostingViews. They do not capture the user's desktop or use real sessions.
@Test @MainActor func renderDesignSnapshots() throws {
    guard let path = ProcessInfo.processInfo.environment["CONTEXT_BAR_SNAPSHOT_DIR"] else { return }
    let destination = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try snapshot(GlassAppearancePanel(), size: CGSize(width: 290, height: 270), to: destination.appendingPathComponent("appearance.png"))
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    fixture.model.isDesignPreview = true
    fixture.model.showingSavings = true
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("dashboard.png"))
    fixture.model.language = .english
    try snapshot(Dashboard(model: fixture.model).environment(\.locale, fixture.model.language.locale),
        size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("dashboard-en.png"))
    fixture.model.togglePricingMode()
    try snapshot(Dashboard(model: fixture.model).environment(\.locale, fixture.model.language.locale),
        size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("dashboard-actual-en.png"))
    fixture.model.language = .chinese
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786),
        to: destination.appendingPathComponent("dashboard-actual.png"))
    fixture.model.togglePricingMode()
    fixture.model.showingSavings = false
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("inspector.png"))
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("inspector-light.png"), scheme: .light)
    try snapshot(MenuContent(model: fixture.model), size: CGSize(width: 316, height: 400), to: destination.appendingPathComponent("menu-light.png"), scheme: .light)
    try snapshot(MenuContent(model: fixture.model), size: CGSize(width: 316, height: 356), to: destination.appendingPathComponent("menu.png"))
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 880, height: 640), to: destination.appendingPathComponent("inspector-compact.png"))
    fixture.model.language = .english
    try snapshot(Dashboard(model: fixture.model).environment(\.locale, fixture.model.language.locale), size: CGSize(width: 880, height: 640), to: destination.appendingPathComponent("inspector-compact-en.png"), scheme: .light)
    try snapshot(WorkbenchSettings(model: fixture.model), size: CGSize(width: 340, height: 360), to: destination.appendingPathComponent("shared-settings.png"), scheme: .light)
    fixture.model.language = .chinese
    fixture.model.selectedKind = "plugins.recommendations"
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("recommendations.png"))
    let project = try #require(fixture.model.project)
    let baseline = try #require(fixture.model.selected)
    let preview = try fixture.model.store.preview(project: project, baseline: baseline, target: .memory, enabled: false)
    try snapshot(ConfigPreviewSheet(model: fixture.model, preview: preview), size: CGSize(width: 570, height: 540), to: destination.appendingPathComponent("config-preview.png"))
    var inherited = try #require(fixture.model.selected)
    inherited.id = "inherited-preview"
    inherited.complete = false
    inherited.blocks = []
    inherited.issue = "继承或分页增量，不能证明 block 缺席"
    fixture.model.sessions.insert(inherited, at: 0)
    fixture.model.selectedID = inherited.id
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 880, height: 640), to: destination.appendingPathComponent("incomplete.png"))
    fixture.model.sessions = []; fixture.model.project = nil; fixture.model.operations = []; fixture.model.verification = [:]; fixture.model.configuredValues = [:]
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("empty.png"))
}

@MainActor
private func snapshot<V: View>(_ view: V, size: CGSize, to url: URL, scheme: ColorScheme = .dark) throws {
    let content = view.environment(\.colorScheme, scheme).environment(\.locale, Locale(identifier: "zh_CN")).environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
    let hosting = NSHostingView(rootView: content)
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    window.contentView = hosting
    hosting.setFrameSize(size)
    hosting.layoutSubtreeIfNeeded()
    hosting.displayIfNeeded()
    let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    bitmap.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    try data.write(to: url)
    window.contentView = nil
}

@Test @MainActor func defaultSelectionPrefersCompleteEvidenceAndPreservesManualSelection() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    let complete = try #require(fixture.model.selected)
    var inherited = complete
    inherited.id = "inherited"
    inherited.complete = false
    inherited.blocks = []
    inherited.issue = "继承或分页增量，不能证明 block 缺席"
    fixture.model.sessions = [inherited, complete]
    fixture.model.selectedID = nil
    #expect(fixture.model.selected?.id == complete.id)
    fixture.model.selectedID = inherited.id
    #expect(fixture.model.selected?.id == inherited.id)
    fixture.model.selectUsableSession()
    #expect(fixture.model.selected?.id == complete.id)
}

@Test @MainActor func partialEvidenceShowsObservedBlocksWithoutClaimingAbsence() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    var partial = try #require(fixture.model.selected)
    partial.complete = false
    partial.blocks = partial.blocks.filter { $0.kind == "host_skills.instructions" }
    #expect(InspectorItem.primary[0].tokens(in: partial) == TokenEstimate.count(String(repeating: "示", count: 6840)))
    #expect(InspectorItem.primary[0].observation(in: partial) == "部分观测")
    #expect(InspectorItem.primary[1].tokens(in: partial) == nil)
    #expect(InspectorItem.primary[1].observation(in: partial) == "未知")
}

@Test @MainActor func dataDirectoryRejectsProjectWithoutChangingSource() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    let original = fixture.model.codexHome
    do {
        try fixture.model.setCodexHome(try #require(fixture.model.project))
        Issue.record("Project directory must not replace Codex data directory")
    } catch {
        #expect(fixture.model.codexHome == original)
        #expect(fixture.defaults.string(forKey: "codexHome") == original.path)
    }
    let home = fixture.root.appendingPathComponent("valid-home")
    try FileManager.default.createDirectory(at: home.appendingPathComponent("sessions"), withIntermediateDirectories: true)
    try fixture.model.setCodexHome(home)
    #expect(fixture.model.codexHome == home.resolvingSymlinksInPath())
    #expect(fixture.model.sessions.isEmpty)
}

@Test @MainActor func pricingToggleSwitchesAllSavingsAndDoesNotPersistActualMode() throws {
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    let model = fixture.model
    #expect(model.pricingMode == .maximum)
    let maximum = try #require(model.displayedSavings?.all30.savingsUSD)
    model.togglePricingMode()
    #expect(model.pricingMode == .actual)
    let actual = try #require(model.displayedSavings?.all30.savingsUSD)
    #expect(maximum.upperBound > actual.upperBound)
    #expect(model.displayedSavings?.current7.savingsUSD == model.actualSavings?.current7.savingsUSD)
    #expect(model.displayedSavings?.all30.byTargetUSD == model.actualSavings?.all30.byTargetUSD)
    let restarted = AppModel(defaults: fixture.defaults, startsMonitoring: false,
        operationDirectory: fixture.root.appendingPathComponent("operations"))
    #expect(restarted.pricingMode == .maximum)
    model.togglePricingMode()
    #expect(model.displayedSavings?.all30.savingsUSD == maximum)
}

@Test @MainActor func workbenchDefaultsToProjectAndPreviewsWithoutNavigationOrWrites() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    let model = fixture.model
    model.showingSavings = true
    #expect(model.savingsScope == .project)
    #expect(model.savingsDays == 30)
    #expect(model.pricingMode == .maximum)
    #expect(model.activeSavings?.savingsUSD == model.savings?.current30.savingsUSD)
    model.savingsDays = 7
    model.togglePricingMode()
    #expect(model.activeSavings?.savingsUSD == model.actualSavings?.current7.savingsUSD)
    model.savingsScope = .all
    model.previewOptimization(.memory)
    #expect(model.preview == nil)
    #expect(model.activeSavings?.savingsUSD == model.actualSavings?.all7.savingsUSD)
    model.savingsScope = .project
    model.previewOptimization(.memory)
    let preview = try #require(model.preview)
    #expect(model.showingSavings)
    #expect(model.optimizationTarget == .memory)
    #expect(preview.target.isGlobal)
    #expect(!FileManager.default.fileExists(atPath: preview.file.path))
    model.preview = nil
    model.showEvidence(.memory)
    #expect(!model.showingSavings)
    #expect(model.selectedItem.target == .memory)
}

@Test @MainActor func menuOpensPendingWorkInsteadOfGenericStatistics() throws {
    let fixture = try InspectorFixture()
    defer { fixture.cleanup() }
    let model = fixture.model
    model.savingsScope = .all
    model.optimizationTarget = .plugins
    #expect(model.menuActionTitle == "继续验证")
    model.openWorkbench()
    #expect(model.showingSavings)
    #expect(model.savingsScope == .project)
    #expect(model.optimizationTarget == .skillCatalog)
    #expect(model.optimizationStatus(.skillCatalog) == "已保存，等待新任务验证")
}

@Test @MainActor func renderWorkbenchSnapshots() throws {
    guard let path = ProcessInfo.processInfo.environment["CONTEXT_BAR_SNAPSHOT_DIR"] else { return }
    let destination = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    let model = fixture.model
    model.isDesignPreview = true
    model.showingSavings = true
    try snapshot(Dashboard(model: model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("workbench-light.png"), scheme: .light)
    try snapshot(Dashboard(model: model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("workbench-dark.png"))
    model.language = .english
    try snapshot(Dashboard(model: model), size: CGSize(width: 880, height: 640), to: destination.appendingPathComponent("workbench-compact-en.png"), scheme: .light)
    model.language = .chinese
    model.savingsScope = .all
    try snapshot(Dashboard(model: model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("workbench-all.png"), scheme: .light)
    model.savingsScope = .project
    model.savings = nil; model.actualSavings = nil; model.sessions = []
    try snapshot(Dashboard(model: model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("workbench-no-data.png"), scheme: .light)
    model.project = nil
    try snapshot(Dashboard(model: model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("workbench-welcome.png"), scheme: .light)
    let pending = try InspectorFixture()
    defer { pending.cleanup() }
    pending.model.isDesignPreview = true; pending.model.showingSavings = true
    try snapshot(Dashboard(model: pending.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("workbench-pending.png"), scheme: .light)
}

@Test func appearanceThemeResolvesExplicitAndSystemModes() {
    #expect(AppTheme.system.colorScheme == nil)
    #expect(AppTheme.light.colorScheme == .light)
    #expect(AppTheme.dark.colorScheme == .dark)
}
