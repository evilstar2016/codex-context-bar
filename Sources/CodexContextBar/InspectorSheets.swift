import AppKit
import ContextCore
import SwiftUI

struct ConfigPreviewSheet: View {
    @Bindable var model: AppModel
    let preview: ConfigPreview
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "slider.horizontal.3").foregroundStyle(InspectorTheme.teal)
                Text("\(preview.enabled ? "开启" : "关闭")\(preview.target.title)").font(.system(size: 23, weight: .semibold))
            }
            Text(preview.target.isGlobal ? "用户级 · 影响所有项目的新任务" : "项目级 · 仅影响当前项目的新任务")
                .font(.system(size: 13)).foregroundStyle(InspectorTheme.amber)
            Text(preview.target.consequence).font(.system(size: 14)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(InspectorTheme.secondary)
            InspectorDivider()
            VStack(alignment: .leading, spacing: 12) {
                Text("[\(preview.target.table)]").foregroundStyle(InspectorTheme.secondary)
                Text("修改前  \(preview.target.key) = \(preview.before.map(String.init) ?? "未设置")")
                Text("修改后  \(preview.target.key) = \(String(preview.enabled))").foregroundStyle(InspectorTheme.observed)
            }.font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
            InspectorDivider()
            Text(preview.file.path).font(.system(size: 11, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(InspectorTheme.secondary).textSelection(.enabled)
            Text("保存后显示待验证。请在同一目录新建任务，已有会话不会因此删除继承的历史。")
                .font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary).lineSpacing(3)
            HStack(spacing: 12) {
                Button("取消") { model.preview = nil }.buttonStyle(InspectorButtonStyle()).keyboardShortcut(.cancelAction)
                Button("保存配置", action: model.applyPreview).buttonStyle(InspectorButtonStyle(prominent: true))
            }
        }
        .padding(30).frame(width: 570)
        .foregroundStyle(InspectorTheme.text).background { GlassBackground() }.preferredColorScheme(.dark)
    }
}

struct OperationHistorySheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var undoCandidate: ConfigOperation?
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("修改记录").font(.system(size: 24, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(model.project?.lastPathComponent ?? "尚未选择项目").foregroundStyle(InspectorTheme.secondary)
            InspectorDivider()
            if model.operations.isEmpty {
                Text("还没有配置修改。保存后的操作与验证结果会出现在这里。")
                    .foregroundStyle(InspectorTheme.secondary).padding(.vertical, 32)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.operations) { operation in
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(operation.target.title) → \(operation.enabled ? "开启" : "关闭")").font(.system(size: 15, weight: .medium))
                                    Text(operation.createdAt.formatted()).font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                                    if let result = model.verification[operation.id] {
                                        Text(result.message).font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
                                        if let id = result.sessionID { Text(id).font(.system(size: 11, design: .monospaced)).textSelection(.enabled) }
                                    }
                                }
                                Spacer()
                                if !operation.restored { Button("撤销") { undoCandidate = operation } }
                            }.padding(.vertical, 20)
                            InspectorDivider()
                        }
                    }
                }.frame(maxHeight: 400)
            }
        }.padding(30).frame(width: 640)
        .foregroundStyle(InspectorTheme.text).background { GlassBackground() }.preferredColorScheme(.dark)
        .alert("撤销这次配置修改？", isPresented: Binding(get: { undoCandidate != nil }, set: { if !$0 { undoCandidate = nil } })) {
            Button("取消", role: .cancel) { undoCandidate = nil }
            Button("撤销") { if let operation = undoCandidate { model.undo(operation) }; undoCandidate = nil }
        } message: { Text("只恢复本次目标键，保留其他修改。恢复效果仍需新会话观察。") }
    }
}
