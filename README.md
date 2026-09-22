# Codex Context Bar

用 Swift 原生实现的 macOS 菜单栏应用，观察 Codex 初始会话头、预览配置修改，并从新任务日志验证结果。

首版以中文界面提供本地分析。SwiftUI + Foundation，无 Node、React、WebView 或常驻 HTTP 服务。TOML 校验使用固定版本的纯 Swift 库 TOMLDecoder。

## 运行

要求 macOS 14+、Swift 6.0+ / Xcode 16+。开发验证环境：Xcode 26.2、Swift 6.2.3、Apple Silicon。

```sh
swift test
./scripts/build-app.sh
open 'build/Codex Context Bar.app'
```

也可在 Xcode 打开 `Package.swift`。构建脚本生成本机架构的 `.app`，默认 ad-hoc 签名，仅用于本机开发；尚未提供 Developer ID 公证或自动更新。站外发布需要有效签名、公证和 Intel/Apple Silicon 兼容测试。

首次启动，在菜单栏点击图标 → 选择项目 → 打开检查器。默认读取 `~/.codex`，支持 `CODEX_HOME`（启动进程的环境变量）或在界面选择数据目录。Finder 启动不一定继承 shell 环境。

## 已实现

- 菜单栏摘要、独立详情窗口、项目和会话选择。
- 原生 JSONL 解析，基于 role 和 `content_item_kinds`，不会把正文引用的 block 标签当成真实注入。
- 完整性判断：ordinal 从零连续、无继承历史、有完整 world state、developer/user metadata 和首个 turn context。
- 自动技能目录（项目级）、Memory 与 Plugins（用户级）的配置预览、显式保存、撤销和新任务观察。
- 完整 TOML 校验、修改前指纹检查、原子替换、应用内跨进程锁；保留无关内容及目标行注释。
- 操作记录不保存配置全文或会话正文，只保存目标键原值、路径、时间和指纹。撤销恢复目标键，保留无关修改。
- 每分钟检查日志元数据，缓存未变化文件的解析结果；手动刷新。每次最多枚举 20,000 个条目、读取最近修改的 500 个日志，展示当前精确 cwd 的最近 30 个会话。达到上限明确提示。

## 使用闭环

1. 选择项目及一个完整会话头作为基线。
2. 点击“预览关闭”或“预览开启”，查看具体键、文件和影响范围。
3. 保存后显示待验证。已有会话中的继承历史不会被删除。
4. 在 **Codex Desktop 使用同一目录新建 local task**，不要用 fork 或另一个 worktree 代替。
5. 刷新或等待下一次检查；应用寻找修改后、同 cwd、同 source 的完整新会话头。
6. 在修改记录查看符合预期、不符合预期或证据不足。需要时撤销。

全局控制会影响其它项目的新会话。隐藏技能目录会减少自动技能发现说明；关闭 Plugins 会关闭插件功能，不只是推荐列表。Memory 开关不删除记忆文件。

## 证据与兼容边界

- 兼容依据是 2026-09-17—18 对 Desktop 内置 runtime `0.154.0-alpha.6.2` 的调查；新版需重新观察。
- 界面显示**日志里的初始会话头字符数**，不是实时完整请求、精确 Token 数或保证节省的账单。当前未实现 tokenizer。
- “新任务观测符合预期”只证明相关 metadata 在该新任务存在或缺席，不证明唯一因果，也不证明功能可用性。
- 日志 `source` 不能单独认证 Desktop 宿主链路。应用不创建任务、不抓取 WebSocket、不修改远程 feature flag。
- 缺少 metadata、fork、分页增量、截断和无法识别格式保持未知；绝不将未知当作零成本或已关闭。
- 配置层级、profile、managed requirements 和 Desktop 远程覆盖并未完整求值；配置写入结果始终与观测分离。
- 项目与 worktree 按真实 cwd 分开。归档会话暂不扫描。
- 推荐插件 block 独立关闭和项目层单技能禁用不作为可靠开关提供。
- TOML 点号键、inline table、目标 table 的特殊布局可能无法保留格式，应用会拒绝修改，允许用户手动处理。
- 新建的配置文件或空 table 在撤销后可能保留；撤销保证目标键恢复，不承诺逐字节还原整份文件。
- 检测到其它写入会拒绝过期操作；非合作程序在最后检查与 rename 之间写入的极短竞态无法完全消除。

## 本地数据

- 设置：应用 UserDefaults（项目目录、Codex 数据目录）。
- 操作记录：`~/Library/Application Support/CodexContextBar/operations/`，目录权限 0700、记录 0600。
- 配置写入仅在预览后点击“保存配置”时发生。应用运行时不联网、不上传、不读取登录凭据。
- 测试只使用临时目录和合成数据；仓库不包含真实会话、用户配置或令牌。

## 结构

```text
Sources/ContextCore/       会话模型、解析、扫描、TOML 编辑、操作与验证
Sources/CodexContextBar/   SwiftUI 菜单栏、详情与状态模型
Tests/ContextCoreTests/    合成日志与隔离文件系统回归测试
Resources/Info.plist       macOS 菜单栏应用元数据
scripts/build-app.sh       构建并本地签名 .app
```

后续重点：精确 Token 计量、文件事件驱动扫描、更多说明块的可控性、版本兼容样本，以及签名发布。

## 界面设计与验证

采用深石墨色双栏检查器：左侧选择会话内容，右侧分别呈现已保存配置、历史观测和新任务验证状态。菜单栏只汇总每个控制项最新一次操作；推荐插件保持只读观察。

![原生 SwiftUI 检查器](docs/design/inspector.png)

图片来自实际 SwiftUI 视图与合成测试数据，不包含用户会话。25 项自动化测试覆盖核心逻辑与界面状态；可选原生布局快照：

```sh
CONTEXT_BAR_SNAPSHOT_DIR=/tmp/context-bar-snapshots swift test
```

设计对照与验证边界见 [design-qa.md](design-qa.md)。
