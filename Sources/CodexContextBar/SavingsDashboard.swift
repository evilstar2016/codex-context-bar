import SwiftUI
import ContextCore

struct SavingsDashboard: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("收益仪表盘")
                        .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
                    Text("三项说明可能占用多少上下文")
                        .font(.system(size: 30, weight: .semibold))
                    Text("按完整初始会话头中的实际字符量汇总。假设今后的同类说明不再注入，这些字符可能从初始上下文中减少。")
                        .font(.system(size: 14)).foregroundStyle(InspectorTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if model.project == nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("先选择一个项目", systemImage: "folder")
                            .font(.system(size: 20, weight: .medium))
                        Text("选择项目后读取当前目录和所有项目的近 7 天、30 天会话。")
                            .foregroundStyle(InspectorTheme.secondary)
                        Button("选择项目", action: model.chooseProject)
                            .buttonStyle(InspectorButtonStyle(prominent: true)).frame(width: 200)
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(InspectorTheme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                } else if let summary = model.savings {
                    observationBanner(summary)
                    HStack(alignment: .top, spacing: 20) {
                        scopeSection("当前项目", detail: model.project?.lastPathComponent ?? "", seven: summary.current7, thirty: summary.current30)
                        scopeSection("所有项目", detail: "本机 Codex sessions", seven: summary.all7, thirty: summary.all30)
                    }
                    breakdown(summary.all30)
                    if summary.all30.incompleteCount > 0 {
                        Label("另有 \(summary.all30.incompleteCount) 条近 30 天记录的初始证据不完整，未计入字符总量。", systemImage: "info.circle")
                            .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
                    }
                    if let warning = model.warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(InspectorTheme.amber)
                    }
                    Text("统计基于已读取的本地会话头；字符不是精确 Token 或账单节省。关闭自动技能目录需逐项目设置；关闭 Plugins 也会停用插件功能。配置写入后仍需用新任务验证。")
                        .font(.system(size: 12)).lineSpacing(4).foregroundStyle(InspectorTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("查看配置与会话证据") { model.showingSavings = false }
                        .buttonStyle(InspectorButtonStyle(prominent: true)).frame(width: 240)
                } else {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text("正在读取会话记录…")
                    }.foregroundStyle(InspectorTheme.secondary)
                }
            }
            .padding(30)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }

    private func observationBanner(_ summary: SavingsSummary) -> some View {
        let observed = model.sessions.first(where: \.complete).map { session in
            ControlTarget.allCases.filter(session.contains).count
        }
        return HStack(spacing: 14) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 23)).foregroundStyle(InspectorTheme.teal)
            VStack(alignment: .leading, spacing: 4) {
                Text(observed.map { "当前项目最近的完整会话观测到 \($0) / 3 项" } ?? "当前项目尚无完整会话头")
                    .font(.system(size: 16, weight: .medium))
                Text("近 30 天所有项目中，\(summary.all30.allThreeCount) 个完整会话同时出现三项说明。")
                    .font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InspectorTheme.selection.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scopeSection(_ title: String, detail: String, seven: SavingsSnapshot, thirty: SavingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 19, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 10) {
            Text(period).font(.system(size: 13)).foregroundStyle(InspectorTheme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(snapshot.sessionCount > 0 ? snapshot.characters.formatted() : "—")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                Text("字符").font(.system(size: 12)).foregroundStyle(InspectorTheme.secondary)
            }
            Text(snapshot.sessionCount > 0 ? "\(snapshot.sessionCount) 个完整会话 · \(snapshot.projectCount) 个项目" : "暂无完整会话头")
                .font(.system(size: 11)).foregroundStyle(InspectorTheme.secondary)
            if snapshot.initialCharacters > 0 {
                Text("占已观测初始会话头 \(Int(Double(snapshot.characters) / Double(snapshot.initialCharacters) * 100))%")
                    .font(.system(size: 11)).foregroundStyle(InspectorTheme.teal)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(InspectorTheme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(InspectorTheme.line))
    }

    private func breakdown(_ snapshot: SavingsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("构成 · 所有项目近 30 天")
                .font(.system(size: 19, weight: .semibold))
            ForEach(ControlTarget.allCases) { target in
                let value = snapshot.byTarget[target, default: 0]
                HStack(spacing: 16) {
                    Text(target.title).frame(width: 100, alignment: .leading)
                    ProgressView(value: Double(value), total: Double(max(snapshot.characters, 1)))
                        .tint(InspectorTheme.teal)
                    Text(value.formatted()).monospacedDigit().frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 13))
            }
        }
        .padding(20)
        .background(InspectorTheme.raised.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
