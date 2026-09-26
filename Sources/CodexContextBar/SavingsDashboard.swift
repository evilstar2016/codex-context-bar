import SwiftUI
import ContextCore

struct SavingsDashboard: View {
    @Bindable var model: AppModel
    @State private var showingSettings = false
    @State private var showingCalculation = false
    @State private var undoCandidate: ConfigOperation?

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 200)
            Divider()
            VStack(spacing: 0) {
                toolbar
                Divider()
                if model.project == nil {
                    welcome
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            summary
                            Divider()
                            adjustments
                            if let warning = model.warning {
                                Label(model.language.text(warning), systemImage: "info.circle")
                                    .font(.callout).foregroundStyle(InspectorTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            calculation
                        }
                        .padding(30)
                    }
                    footer
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(InspectorTheme.background)
        }
        .alert(model.language.text("撤销这次配置修改？"), isPresented: Binding(
            get: { undoCandidate != nil }, set: { if !$0 { undoCandidate = nil } })) {
            Button(model.language.text("取消"), role: .cancel) { undoCandidate = nil }
            Button(model.language.text("撤销")) {
                if let operation = undoCandidate { model.undo(operation) }
                undoCandidate = nil
            }
        } message: {
            Text(model.language.text("只恢复本次目标键，保留其他修改。恢复效果仍需新会话观察。"))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                if let url = Bundle.module.url(forResource: "AppLogo", withExtension: "png"),
                   let logo = NSImage(contentsOf: url) {
                    Image(nsImage: logo)
                        .resizable().interpolation(.high).frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                }
                Text("Context Bar").font(.system(size: 17, weight: .semibold))
                Text(model.language.text("让 AI 专注于重要的内容"))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            .padding(.horizontal, 12).padding(.top, 26)

            VStack(spacing: 4) {
                scopeButton(model.project?.lastPathComponent ?? model.language.text("选择项目"),
                    symbol: "folder", selected: model.savingsScope == .project) {
                    if model.project == nil { model.chooseProject() }
                    else { model.savingsScope = .project }
                }
                scopeButton(model.language.text("所有项目"), symbol: "folder.on.folder",
                    selected: model.savingsScope == .all) { model.savingsScope = .all }
                    .disabled(model.project == nil)
            }
            Spacer()
            VStack(spacing: 4) {
                Button { model.showingHistory = true } label: {
                    Label(model.language.text("修改记录"), systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                .disabled(model.project == nil)
                Button { showingSettings = true } label: {
                    Label(model.language.text("设置"), systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                .popover(isPresented: $showingSettings) { WorkbenchSettings(model: model) }
            }
            .buttonStyle(.plain).font(.system(size: 13))
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 12)
        .background { GlassBackground() }
    }

    private func scopeButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(selected ? InspectorTheme.selection : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if model.savingsScope == .project {
                Text(model.language.text("当前项目")).foregroundStyle(InspectorTheme.secondary)
                Text("/").foregroundStyle(.tertiary)
                ProjectMenu(model: model).labelStyle(.titleOnly)
            } else {
                Label(model.language.text("所有项目"), systemImage: "folder.on.folder")
            }
            Spacer(minLength: 8)
            Button { Task { await model.refresh() } } label: {
                if model.refreshing { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise") }
            }
            .disabled(model.refreshing || model.project == nil)
            .help(model.language.text("检查新的会话记录"))
            .accessibilityLabel(model.language.text("刷新会话"))
            Picker(model.language.text("时间范围"), selection: $model.savingsDays) {
                Text(model.language.text("近 7 天")).tag(7)
                Text(model.language.text("近 30 天")).tag(30)
            }
            .labelsHidden().frame(width: 112)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 28).frame(height: 54)
    }

    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                introduction.frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                Divider().frame(height: 116)
                amount.frame(width: 250, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 20) {
                introduction
                amount
            }
        }
        .padding(.vertical, 12)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.language.text("让上下文更精简"))
                .font(.system(size: 26, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(model.language.text("逐项查看影响，再决定是否调整。"))
                .font(.system(size: 14)).foregroundStyle(InspectorTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.savingsScope == .all {
                Text(model.language.text("此处汇总所有项目；配置修改需回到当前项目。"))
                    .font(.callout).foregroundStyle(InspectorTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var amount: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.language.text("潜在节省")).font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
            Text(money(model.activeSavings?.savingsUSD))
                .font(.system(size: 32, weight: .semibold)).monospacedDigit()
                .foregroundStyle(InspectorTheme.teal)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let snapshot = model.activeSavings {
                Text(String(format: model.language.text("API 等价估算 · %d / %d 条响应可计价"),
                    snapshot.savingsCoverage, snapshot.responseCount))
                    .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
            } else {
                Text(model.language.text(model.refreshing ? "正在读取会话记录…" : "暂无足够数据"))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            HStack(spacing: 9) {
                Text(model.language.text(model.pricingMode == .maximum ? "按 gpt-6-astra 模拟" : "按实际模型估算"))
                Button(model.language.text(model.pricingMode == .maximum ? "按实际使用模型" : "恢复最高价估算"),
                    action: model.togglePricingMode)
                    .buttonStyle(.plain).underline()
                    .help(model.language.text("切换费用与节省的计价口径"))
                    .accessibilityLabel(model.language.text("切换费用与节省的计价口径"))
            }
            .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
        }
    }

    private var adjustments: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.language.text("可调整的说明")).font(.system(size: 17, weight: .semibold))
            VStack(spacing: 0) {
                ForEach(ControlTarget.allCases) { target in
                    adjustment(target)
                    if target != ControlTarget.allCases.last { Divider() }
                }
            }
        }
    }

    private func adjustment(_ target: ControlTarget) -> some View {
        let expanded = model.optimizationTarget == target
        return VStack(alignment: .leading, spacing: 0) {
            Button { model.optimizationTarget = expanded ? nil : target } label: {
                HStack(spacing: 14) {
                    Image(systemName: target == .plugins ? "puzzlepiece.extension" : "doc.text")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(expanded ? InspectorTheme.teal : InspectorTheme.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.language.text(target == .plugins ? "Plugins" : target.title))
                            .font(.system(size: 15, weight: .medium))
                        Text(model.language.text(target.isGlobal ? "影响所有项目" : "仅当前项目"))
                            .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(model.activeSavings?.byTarget[target].map {
                            String(format: model.language.text("约 %@ Token"), $0.formatted())
                        } ?? "— Token")
                            .font(.system(size: 13)).monospacedDigit()
                            .foregroundStyle(InspectorTheme.secondary)
                        if model.savingsScope == .project, model.configuredValues[target] == false || model.result(for: target) != nil {
                            Text(model.language.text(model.optimizationStatus(target)))
                                .font(.system(size: 11)).foregroundStyle(statusColor(target))
                        }
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 12)
                }
                .padding(.horizontal, 16).padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(model.language.text(expanded ? "已展开" : "已折叠"))
            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.language.text(target.consequence))
                        .font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.savingsScope == .all {
                        Button(model.language.text("回到当前项目以修改")) { model.savingsScope = .project }
                            .buttonStyle(.bordered)
                    } else {
                        targetActions(target)
                    }
                }
                .padding(.leading, 58).padding(.trailing, 20).padding(.bottom, 20)
            }
        }
        .background(expanded ? InspectorTheme.selection.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func targetActions(_ target: ControlTarget) -> some View {
        let state = model.result(for: target)?.state
        if let message = model.configProblems[target] {
            Text(message).font(.callout).foregroundStyle(InspectorTheme.amber)
        } else if state == .waiting || state == .mismatch || state == .configChanged {
            VStack(alignment: .leading, spacing: 6) {
                Label(model.language.text(model.optimizationStatus(target)), systemImage: "clock")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(InspectorTheme.amber)
                Text(model.language.text(state == .waiting
                    ? "在 Codex 的同一项目新建任务，然后回来检查新记录。已有会话仍可能保留旧上下文。"
                    : "新记录或配置与预期不同，请查看会话依据后重新预览。"))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if state == .observed {
            Label(model.language.text("新任务已验证"), systemImage: "checkmark.circle")
                .font(.callout).foregroundStyle(InspectorTheme.observed)
        }
        if model.preferredSession?.complete != true {
            Text(model.language.text("需要当前项目的完整会话头，才能预览配置修改。"))
                .font(.callout).foregroundStyle(InspectorTheme.secondary)
        }
        HStack(spacing: 16) {
            if state == .waiting || state == .mismatch {
                Button(model.language.text(model.refreshing ? "正在检查…" : "检查新记录")) { Task { await model.refresh() } }
                    .buttonStyle(.borderedProminent).disabled(model.refreshing)
            } else {
                Button(model.language.text(model.configuredValues[target] == false ? "预览恢复开启" : "预览这项修改")) {
                    model.previewOptimization(target)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.preferredSession?.complete != true || model.configProblems[target] != nil)
            }
            Button(model.language.text("查看会话依据")) { model.showEvidence(target) }
                .buttonStyle(.plain).foregroundStyle(InspectorTheme.teal)
        }
        .controlSize(.large).font(.system(size: 13))
        if let operation = model.operation(for: target), !operation.restored {
            Button(model.language.text("撤销这次修改")) { undoCandidate = operation }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
        }
    }

    private func statusColor(_ target: ControlTarget) -> Color {
        switch model.result(for: target)?.state {
        case .waiting, .mismatch, .configChanged: InspectorTheme.amber
        case .observed: InspectorTheme.observed
        default: InspectorTheme.secondary
        }
    }

    private var calculation: some View {
        DisclosureGroup(model.language.text("计算说明与覆盖范围"), isExpanded: $showingCalculation) {
            VStack(alignment: .leading, spacing: 8) {
                if let snapshot = model.activeSavings {
                    Text(String(format: model.language.text("历史费用估算：%@ · 覆盖 %d / %d"),
                        (model.pricingMode == .maximum ? snapshot.cost : snapshot.actualCost).map(usd) ?? "—",
                        model.pricingMode == .maximum ? snapshot.costCoverage : snapshot.actualCostCoverage, snapshot.responseCount))
                    ForEach(ControlTarget.allCases) { target in
                        HStack {
                            Text(model.language.text(target.title))
                            Spacer()
                            Text(money(snapshot.byTargetUSD[target])).monospacedDigit()
                        }
                    }
                }
                Text(model.language.text("美元为 API 等价估算，并非订阅账单。区间反映目标文本的缓存归属不确定性；上下文 Token 仍按 UTF-8 字节近似，未模拟缓存重建。自动技能目录需逐项目关闭。"))
                Text(String(format: model.language.text("内置价表：%@（未实时核验）"), InputPrice.checkedAt))
            }
            .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            .fixedSize(horizontal: false, vertical: true).padding(.top, 10)
        }
        .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock").accessibilityHidden(true)
            Text(model.language.text("仅在本机分析 · 保存前可检查配置差异"))
            Spacer(minLength: 8)
            if model.isDesignPreview { Text(model.language.text("示例数据")) }
            else if let date = model.lastRefresh { Text(date.formatted(date: .omitted, time: .shortened)) }
        }
        .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
        .padding(.horizontal, 30).padding(.vertical, 16)
        .overlay(alignment: .top) { Divider().padding(.horizontal, 30) }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "folder.badge.plus").font(.system(size: 36, weight: .light)).foregroundStyle(InspectorTheme.teal)
            Text(model.language.text("从一个项目开始")).font(.system(size: 26, weight: .semibold))
            Text(model.language.text("选择你在 Codex 中使用的项目目录，查看上下文和可调整的说明。"))
                .font(.body).foregroundStyle(InspectorTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(model.language.text("选择项目"), action: model.chooseProject)
                .buttonStyle(.borderedProminent).controlSize(.large)
            Text(model.language.text("只读取本机会话；预览后才会修改配置。"))
                .font(.callout).foregroundStyle(InspectorTheme.secondary)
        }
        .frame(maxWidth: 430, alignment: .leading).padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func money(_ range: ClosedRange<Double>?) -> String {
        guard let range else { return "—" }
        if range.lowerBound == range.upperBound { return "≈\(usd(range.lowerBound))" }
        return "\(usd(range.lowerBound))–\(usd(range.upperBound))"
    }

    private func usd(_ value: Double) -> String {
        if value == 0 { return "$0.00" }
        if value > 0 && value < 0.0001 { return "<$0.0001" }
        return String(format: value < 0.01 ? "$%.4f" : "$%.2f", value)
    }
}
