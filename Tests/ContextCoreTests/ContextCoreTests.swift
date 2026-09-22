import Foundation
import Testing
@testable import ContextCore

private func fixture(project: String = "/fixture/project", id: String = "baseline", date: Date = Date(timeIntervalSince1970: 1),
                     kinds: [String] = ["host_skills.instructions", "memories.instructions", "plugins.usage_instructions", "plugins.recommendations"],
                     inherited: Bool = false, source: String = "desktop", offset: Int = 0) throws -> Data {
    let time = ISO8601DateFormatter().string(from: date)
    var meta: [String: Any] = ["id": id, "cwd": project, "timestamp": time, "cli_version": "0.154.0-alpha.6.2", "source": source]
    if inherited { meta["forked_from_id"] = "parent" }
    let records: [[String: Any]] = [
        ["type": "session_meta", "payload": meta],
        ["type": "response_item", "payload": ["role": "developer",
            "content": (["generic.developer_instructions"] + kinds).map { ["text": "Body for \($0)"] },
            "internal_chat_message_metadata_passthrough": ["content_item_kinds": ["generic.developer_instructions"] + kinds]]],
        ["type": "response_item", "payload": ["role": "user", "content": [["text": "<skills_instructions>quoted, not real</skills_instructions>"]],
            "internal_chat_message_metadata_passthrough": ["content_item_kinds": ["agents_md.instructions"]]]],
        ["type": "world_state", "payload": ["full": true, "state": [:]]],
        ["type": "turn_context", "payload": ["cwd": project]],
    ]
    return try records.enumerated().reduce(into: Data()) { data, item in
        var record = item.element
        record["ordinal"] = item.offset + offset
        record["timestamp"] = time
        data.append(try JSONSerialization.data(withJSONObject: record))
        data.append(10)
    }
}

private final class Workspace {
    let root: URL
    let project: URL
    let home: URL
    let store: OperationStore
    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("context-bar-test-" + UUID().uuidString)
        project = root.appendingPathComponent("project")
        home = root.appendingPathComponent("codex")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        store = OperationStore(directory: root.appendingPathComponent("operations"), codexHome: home)
    }
    deinit { try? FileManager.default.removeItem(at: root) }
    func baseline(kinds: [String] = ["host_skills.instructions"]) throws -> SessionHeader {
        try #require(HeaderParser.parse(fixture(project: project.path, kinds: kinds), file: root.appendingPathComponent("baseline.jsonl")))
    }
    func read(_ file: URL) throws -> String { try String(contentsOf: file, encoding: .utf8) }
}

@Test func completeHeaderUsesMetadata() throws {
    let header = try #require(HeaderParser.parse(fixture(kinds: []), file: URL(fileURLWithPath: "/fixture.jsonl")))
    #expect(header.complete)
    #expect(!header.contains(.skillCatalog))
    #expect(header.blocks.count == 2)
    #expect(header.characters > 0)
}

@Test func inheritedAndNonzeroOrdinalsCannotProveAbsence() throws {
    for data in [try fixture(inherited: true), try fixture(offset: 40)] {
        let header = try #require(HeaderParser.parse(data, file: URL(fileURLWithPath: "/fixture.jsonl")))
        #expect(!header.complete)
        #expect(header.issue != nil)
    }
}

@Test func truncatedAndMismatchedHeadersAreUnknown() throws {
    let data = try fixture()
    let truncated = Data(data.prefix(data.count / 2))
    #expect(HeaderParser.parse(truncated, file: URL(fileURLWithPath: "/fixture.jsonl"))?.complete == false)
    let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "content_item_kinds", with: "other")
    #expect(HeaderParser.parse(Data(text.utf8), file: URL(fileURLWithPath: "/fixture.jsonl"))?.complete == false)
}

@Test func missingFullStateCannotProveAbsence() throws {
    let text = String(decoding: try fixture(), as: UTF8.self).replacingOccurrences(of: "\"full\":true", with: "\"full\":false")
    #expect(HeaderParser.parse(Data(text.utf8), file: URL(fileURLWithPath: "/fixture.jsonl"))?.complete == false)
}

@Test func preservesCommentsAndUnrelatedKeys() throws {
    let input = "# My config\nmodel = \"example\"\n[skills]\ninclude_instructions = true # keep this\nother = [1, 2]\n"
    let output = try ConfigEditor.edit(input, target: .skillCatalog, value: false)
    #expect(output == input.replacingOccurrences(of: "= true", with: "= false"))
    #expect(try ConfigEditor.value(in: output, target: .skillCatalog) == false)
}

@Test func insertsMissingSectionAndRestoresAbsentKey() throws {
    let output = try ConfigEditor.edit("model = \"example\"\n", target: .memory, value: false)
    #expect(try ConfigEditor.value(in: output, target: .memory) == false)
    let restored = try ConfigEditor.edit(output, target: .memory, value: nil)
    #expect(try ConfigEditor.value(in: restored, target: .memory) == nil)
    #expect(restored.contains("model = \"example\""))
}

@Test func refusesAmbiguousOrInvalidTOML() throws {
    for input in ["[skills]\ninclude_instructions = not-a-bool", "skills = { include_instructions = true }",
                  "skills.include_instructions = true", "[skills]\ninclude_instructions = true\ninclude_instructions = false"] {
        #expect(throws: (any Error).self) { try ConfigEditor.edit(input, target: .skillCatalog, value: false) }
    }
}

@Test func rejectsFakeTableInsideMultilineString() throws {
    let input = "description = \"\"\"\n[skills]\ninclude_instructions = true\n\"\"\"\n"
    #expect(throws: (any Error).self) { try ConfigEditor.edit(input, target: .skillCatalog, value: false) }
}

@Test func preservesOtherTOMLTypes() throws {
    let input = "when = 1979-05-27T07:32:00Z\nlocal = 07:32:00\nnan = nan\narray = [{ x = 1 }, { y = 'two' }]\n[skills]\ninclude_instructions = true\n"
    let after = try ConfigEditor.edit(input, target: .skillCatalog, value: false)
    #expect(after == input.replacingOccurrences(of: "= true", with: "= false"))
}

@Test func applyIsPendingAndUndoPreservesUnrelatedEdits() throws {
    let workspace = try Workspace()
    let baseline = try workspace.baseline()
    let preview = try workspace.store.preview(project: workspace.project, baseline: baseline, target: .skillCatalog, enabled: false)
    let operation = try workspace.store.apply(preview, project: workspace.project)
    let status = try workspace.store.verify(operation, project: workspace.project, sessions: [baseline])
    #expect(status.matched == nil)
    let text = try workspace.read(preview.file) + "\n[other]\nkeep = true\n"
    try text.write(to: preview.file, atomically: true, encoding: .utf8)
    try workspace.store.undo(operation, project: workspace.project)
    let restored = try workspace.read(preview.file)
    #expect(try ConfigEditor.value(in: restored, target: .skillCatalog) == nil)
    #expect(restored.contains("keep = true"))
    #expect(try workspace.store.operations(project: workspace.project).first?.restored == true)
}

@Test func stalePreviewDoesNotOverwriteConfig() throws {
    let workspace = try Workspace()
    let preview = try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .memory, enabled: false)
    try "model = 'changed'\n".write(to: preview.file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try workspace.store.apply(preview, project: workspace.project) }
    #expect(try workspace.read(preview.file) == "model = 'changed'\n")
}

@Test func globalControlsWriteOnlyUserConfig() throws {
    let workspace = try Workspace()
    let preview = try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .plugins, enabled: false)
    #expect(preview.file == workspace.home.appendingPathComponent("config.toml"))
    _ = try workspace.store.apply(preview, project: workspace.project)
    #expect(!FileManager.default.fileExists(atPath: workspace.project.appendingPathComponent(".codex/config.toml").path))
}

@Test func undoRejectsChangedTarget() throws {
    let workspace = try Workspace()
    let preview = try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .memory, enabled: false)
    let operation = try workspace.store.apply(preview, project: workspace.project)
    try "[memories]\nuse_memories = true\n".write(to: preview.file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try workspace.store.undo(operation, project: workspace.project) }
}

@Test func verificationMatchesFreshProjectAndSource() throws {
    let workspace = try Workspace()
    let preview = try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .skillCatalog, enabled: false)
    let operation = try workspace.store.apply(preview, project: workspace.project)
    func fresh(project: String, source: String = "desktop", inherited: Bool = false, kinds: [String] = []) throws -> SessionHeader {
        try #require(HeaderParser.parse(fixture(project: project, id: "fresh", date: Date().addingTimeInterval(10), kinds: kinds,
            inherited: inherited, source: source), file: workspace.root.appendingPathComponent("fresh.jsonl")))
    }
    for invalid in [try fresh(project: "/other"), try fresh(project: workspace.project.path, source: "cli"),
                    try fresh(project: workspace.project.path, inherited: true)] {
        #expect(try workspace.store.verify(operation, project: workspace.project, sessions: [invalid]).matched == nil)
    }
    #expect(try workspace.store.verify(operation, project: workspace.project, sessions: [fresh(project: workspace.project.path)]).matched == true)
    #expect(try workspace.store.verify(operation, project: workspace.project,
        sessions: [fresh(project: workspace.project.path, kinds: ["host_skills.instructions"])]).matched == false)
}

@Test func changedGlobalConfigInvalidatesVerification() throws {
    let workspace = try Workspace()
    let preview = try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .skillCatalog, enabled: false)
    let operation = try workspace.store.apply(preview, project: workspace.project)
    try "model = 'new'".write(to: workspace.home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
    #expect(try workspace.store.verify(operation, project: workspace.project, sessions: []).message.contains("配置已变化"))
}

@Test func symlinkConfigIsRejected() throws {
    let workspace = try Workspace()
    let real = workspace.root.appendingPathComponent("real.toml")
    try "[memories]\nuse_memories = true".write(to: real, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(at: workspace.home.appendingPathComponent("config.toml"), withDestinationURL: real)
    #expect(throws: (any Error).self) {
        try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .memory, enabled: false)
    }
}

@Test func privateJournalContainsNoConfigBody() throws {
    let workspace = try Workspace()
    let file = workspace.home.appendingPathComponent("config.toml")
    try "private_value = 'fixture-secret'\n".write(to: file, atomically: true, encoding: .utf8)
    let preview = try workspace.store.preview(project: workspace.project, baseline: workspace.baseline(), target: .memory, enabled: false)
    let operation = try workspace.store.apply(preview, project: workspace.project)
    let journal = workspace.store.directory.appendingPathComponent(operation.id.uuidString + ".json")
    #expect(!(try workspace.read(journal)).contains("fixture-secret"))
    let mode = try FileManager.default.attributesOfItem(atPath: journal.path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)
}

@Test func scannerFiltersProjectsAndRefreshesChangedLogs() async throws {
    let workspace = try Workspace()
    let root = workspace.home.appendingPathComponent("sessions/2026/09/22")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("session.jsonl")
    try fixture(project: workspace.project.path).write(to: file)
    try fixture(project: "/another", id: "other").write(to: root.appendingPathComponent("other.jsonl"))
    let repository = SessionRepository()
    let initial = try await repository.scan(codexHome: workspace.home, project: workspace.project)
    #expect(initial.sessions.count == 1)
    #expect(initial.sessions.first?.contains(.skillCatalog) == true)
    try fixture(project: workspace.project.path, kinds: []).write(to: file)
    let changed = try await repository.scan(codexHome: workspace.home, project: workspace.project)
    #expect(changed.sessions.first?.contains(.skillCatalog) == false)
}

@Test func readerHandlesChunkBoundariesAndStopsAtInitialEvidence() throws {
    let workspace = try Workspace()
    let file = workspace.root.appendingPathComponent("large.jsonl")
    var text = String(decoding: try fixture(), as: UTF8.self)
    text = text.replacingOccurrences(of: "Body for generic.developer_instructions", with: String(repeating: "x", count: 100_000))
    try Data((text + String(repeating: "not JSON\n", count: 200_000)).utf8).write(to: file)
    let header = try #require(try HeaderParser.read(file))
    #expect(header.complete)
    #expect(header.characters > 100_000)

    let incomplete = text.replacingOccurrences(of: "content_item_kinds", with: "unknown_metadata")
    try Data((incomplete + String(repeating: "not JSON\n", count: 200_000)).utf8).write(to: file)
    let unknown = try #require(try HeaderParser.read(file))
    #expect(!unknown.complete)
    #expect(unknown.issue == "缺少可信 content item metadata")
}
