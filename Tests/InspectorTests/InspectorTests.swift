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
        model.recentProjects = [project.path]
        model.lastRefresh = ISO8601DateFormatter().date(from: "2026-09-22T11:56:00Z")
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
        ["type": "turn_context", "payload": ["cwd": project.path]],
    ]
    let data = try records.enumerated().reduce(into: Data()) { data, record in
        var object = record.element
        object["ordinal"] = record.offset
        data.append(try JSONSerialization.data(withJSONObject: object)); data.append(10)
    }
    return try #require(HeaderParser.parse(data, file: file))
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
    #expect(fixture.model.selectedItem.characters(in: fixture.model.selected) == 2907)
    fixture.model.selectedKind = "plugins.usage_instructions"
    #expect(fixture.model.selectedItem.target == .plugins)
    #expect(fixture.model.selectedItem.scope.contains("所有项目"))
}

@Test @MainActor func absentControlsRemainSelectableAndUnknownIsNotZero() throws {
    let fixture = try InspectorFixture(pending: false)
    defer { fixture.cleanup() }
    var header = try makeHeader(project: try #require(fixture.model.project), file: fixture.root.appendingPathComponent("empty.jsonl"), kinds: [])
    #expect(InspectorItem.items(in: header).count >= 4)
    #expect(InspectorItem.primary[0].characters(in: header) == 0)
    #expect(InspectorItem.primary[0].observation(in: header) == "未观察到")
    header.complete = false
    #expect(InspectorItem.primary[0].characters(in: header) == nil)
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
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 1048, height: 786), to: destination.appendingPathComponent("inspector.png"))
    try snapshot(MenuContent(model: fixture.model), size: CGSize(width: 316, height: 356), to: destination.appendingPathComponent("menu.png"))
    try snapshot(Dashboard(model: fixture.model), size: CGSize(width: 880, height: 640), to: destination.appendingPathComponent("inspector-compact.png"))
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
private func snapshot<V: View>(_ view: V, size: CGSize, to url: URL) throws {
    let content = view.environment(\.locale, Locale(identifier: "zh_CN")).environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
    let hosting = NSHostingView(rootView: content)
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
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
    #expect(InspectorItem.primary[0].characters(in: partial) == 6840)
    #expect(InspectorItem.primary[0].observation(in: partial) == "部分观测")
    #expect(InspectorItem.primary[1].characters(in: partial) == nil)
    #expect(InspectorItem.primary[1].observation(in: partial) == "未知")
}
