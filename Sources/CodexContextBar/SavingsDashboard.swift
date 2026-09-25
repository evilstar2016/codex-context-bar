import SwiftUI
import ContextCore

struct SavingsDashboard: View {
    @Bindable var model: AppModel
    @State private var impactTarget: ControlTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(model.language.text("收益仪表盘"))
                        .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                    Text(model.language.text("关闭三项说明，可能节省多少？"))
                        .font(.system(size: 30, weight: .semibold))
                    Text(model.language.text("按完整初始会话头估算 Token，再用会话模型的标准 API 输入价格换算美元。"))
                        .font(.system(size: 14)).foregroundStyle(InspectorTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if model.project == nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(model.language.text("先选择一个项目"), systemImage: "folder").font(.system(size: 20, weight: .medium))
                        Text(model.language.text("选择项目后查看当前目录和所有项目近 7 天、30 天的估算。"))
                            .foregroundStyle(InspectorTheme.secondary)
                        Button(model.language.text("选择项目"), action: model.chooseProject)
                            .buttonStyle(InspectorButtonStyle(prominent: true)).frame(width: 200)
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(InspectorTheme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                } else if let summary = model.savings {
                    headline(summary.all30)
                    HStack(alignment: .top, spacing: 20) {
                        scopeSection("当前项目", detail: model.project?.lastPathComponent ?? "", seven: summary.current7, thirty: summary.current30)
                        scopeSection("所有项目", detail: model.language.text("本机 Codex 会话"), seven: summary.all7, thirty: summary.all30)
                    }
                    breakdown(summary.all30)
                    if summary.all30.incompleteCount > 0 {
                        Label(String(format: model.language.text("另有 %d 条近 30 天记录证据不完整，未计入。"), summary.all30.incompleteCount), systemImage: "info.circle")
                            .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
                    }
                    if let warning = model.warning {
                        Label(model.language.text(warning), systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(model.language.text("美元为 API 等价估算，并非 Codex 订阅账单或保证节省；仅模拟每会话一次普通输入，不含后续请求和缓存变化。自动技能目录需逐项目关闭。"))
                            .font(.system(size: 12)).lineSpacing(4).foregroundStyle(InspectorTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Link(String(format: model.language.text("价格核对：%@"), InputPrice.checkedAt), destination: URL(string: InputPrice.source)!)
                            .font(.system(size: 12))
                    }
                } else {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text(model.language.text("正在读取会话记录…"))
                    }.foregroundStyle(InspectorTheme.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        .popover(item: $impactTarget, arrowEdge: .trailing) { target in impactPopover(target) }
    }

    private func headline(_ snapshot: SavingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.language.text("所有项目 · 近 30 天潜在节省"))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(observationSummary)
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(snapshot.ordinaryUSD.map { "≈\(usd($0))" } ?? "—")
                    .font(.system(size: 45, weight: .semibold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                Text(String(format: model.language.text("约 %@ Token"), snapshot.tokens.formatted()))
                    .font(.system(size: 15)).foregroundStyle(InspectorTheme.secondary)
            }
            if let cached = snapshot.cachedUSD {
                Text(String(format: model.language.text("若均为缓存读取，约 %@；真实缓存比例未知。"), usd(cached)))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            if snapshot.unpricedSessionCount > 0 {
                Label(String(format: model.language.text("%d 个会话缺少受支持的模型或超出价格适用范围，美元未计入。"), snapshot.unpricedSessionCount), systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InspectorTheme.selection.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scopeSection(_ title: String, detail: String, seven: SavingsSnapshot, thirty: SavingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.language.text(title)).font(.system(size: 19, weight: .semibold))
                Spacer(minLength: 4)
                Text(detail).font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            HStack(spacing: 12) {
                metric("近 7 天", snapshot: seven)
                metric("近 30 天", snapshot: thirty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ period: String, snapshot: SavingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.language.text(period)).font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
            Text(snapshot.ordinaryUSD.map { "≈\(usd($0))" } ?? "—")
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(String(format: model.language.text("约 %@ Token"), snapshot.tokens.formatted()))
                .font(.system(size: 12)).foregroundStyle(InspectorTheme.teal)
            Text(snapshot.sessionCount > 0
                ? String(format: model.language.text("%d 个完整会话 · %d 个项目"), snapshot.sessionCount, snapshot.projectCount)
                : model.language.text("暂无完整会话头"))
                .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
            if snapshot.unpricedSessionCount > 0 {
                Text(String(format: model.language.text("%d 个会话未计价"), snapshot.unpricedSessionCount))
                    .font(.system(size: 11)).foregroundStyle(InspectorTheme.amber)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 134, alignment: .topLeading)
        .background(InspectorTheme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(InspectorTheme.line))
    }

    private func breakdown(_ snapshot: SavingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.language.text("逐项优化 · 所有项目近 30 天"))
                    .font(.system(size: 19, weight: .semibold))
                Spacer()
                Text(model.language.text("先了解影响，再预览关闭"))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            ForEach(ControlTarget.allCases) { target in
                let tokens = snapshot.byTarget[target, default: 0]
                HStack(spacing: 14) {
                    Text(model.language.text(target.title)).frame(width: 104, alignment: .leading)
                    ProgressView(value: Double(tokens), total: Double(max(snapshot.tokens, 1)))
                        .tint(InspectorTheme.teal)
                    Text(String(format: model.language.text("约 %@ Token"), tokens.formatted()))
                        .monospacedDigit().frame(width: 122, alignment: .trailing)
                    Text(snapshot.pricedSessionCount > 0 ? usd(snapshot.byTargetUSD[target, default: 0]) : "—")
                        .monospacedDigit().frame(width: 82, alignment: .trailing)
                    Button(model.language.text("了解并优化")) { impactTarget = target }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .font(.system(size: 13))
            }
        }
        .padding(17)
        .background(InspectorTheme.raised.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private func impactPopover(_ target: ControlTarget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.language.text("关闭后的影响")).font(.system(size: 20, weight: .semibold))
            Text(model.language.text(target.title)).font(.system(size: 15, weight: .medium))
            Text(model.language.text(target.consequence))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            if target == .skillCatalog {
                Text(model.language.text("此项只修改当前项目；所有项目的总计需要分别处理各项目。"))
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            Text(model.language.text("先查看具体配置差异，保存后在同一项目新建任务并检查观测。"))
                .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            Button(model.configuredValues[target] == false ? model.language.text("查看当前状态") : model.language.text("预览关闭")) {
                impactTarget = nil
                model.guideToDisable(target)
            }
            .buttonStyle(InspectorButtonStyle(prominent: true))
        }
        .padding(22).frame(width: 370, alignment: .leading)
        .background { GlassBackground() }
    }

    private func usd(_ value: Double) -> String {
        if value == 0 { return "$0.00" }
        if value > 0 && value < 0.0001 { return "<$0.0001" }
        return String(format: value < 0.01 ? "$%.4f" : "$%.2f", value)
    }

    private var observationSummary: String {
        guard let session = model.sessions.first(where: \.complete) else {
            return model.language.text("当前项目尚无完整会话头")
        }
        let observed = ControlTarget.allCases.filter(session.contains).count
        return String(format: model.language.text("最近完整会话：%d/3 项出现"), observed)
    }
}
