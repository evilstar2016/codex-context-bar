# 开源发布文案 / Launch copy

以下为可直接使用的文案草稿；尚未代发到社交平台。链接统一使用 https://github.com/evilstar2016/codex-context-bar 。

## 一句话介绍

Codex Context Bar：一个专为 Codex 打造的原生 macOS 菜单栏工具，帮你看清上下文、预览配置修改，并用新任务日志检查结果。

## GitHub About

Native macOS menu bar app for inspecting Codex context, estimating usage, and verifying configuration changes locally.

## 中文发布帖

我把 Codex Context Bar 开源了。

用 Codex 时，我想知道：会话里出现了哪些技能、记忆和插件说明？修改相关配置后，新任务里有没有变化？

所以做了一个原生 macOS 菜单栏工具，把这个过程变成四步：看上下文 → 预览修改 → 保存配置 → 用新任务验证。

目前支持：
- 查看上下文构成与近似 Token 数；
- 汇总近 7 / 30 天用量，模拟潜在节省；
- 预览项目级、用户级配置差异，支持撤销；
- 本机分析，中英双语、明暗主题与磨砂玻璃外观。

金额只是 API 等价估算，不是订阅账单，也不承诺节省比例。项目仍处于早期，当前从源码构建，欢迎一起补充版本兼容样本和改进使用体验。

源码：https://github.com/evilstar2016/codex-context-bar

这是独立社区项目，与 OpenAI 无隶属关系。

## 中文短帖

开源了 Codex Context Bar：原生 macOS 菜单栏工具，查看 Codex 上下文、预览配置修改，再用新任务日志验证。支持本机分析、历史用量估算、中英双语和明暗主题。早期版本，欢迎试用与反馈。金额为模拟估算，并非实际账单。
https://github.com/evilstar2016/codex-context-bar

## English launch post

I’m open-sourcing Codex Context Bar, a native macOS menu bar app for understanding your Codex context.

Inspect skill, memory and plugin instructions in local logs, preview a configuration change, then check a fresh task for evidence of the result. The app also summarizes recent usage and estimates potential savings, with explicit coverage and uncertainty.

Built with SwiftUI. Local processing, Chinese/English UI, light/dark themes and adjustable frosted glass.

This is an early source-build release. Dollar amounts are API-equivalent estimates, not subscription charges or promised savings. Compatibility fixtures and feedback are welcome.

https://github.com/evilstar2016/codex-context-bar

Independent community project; not affiliated with or endorsed by OpenAI.

## Short English post

Open source: Codex Context Bar for macOS. Inspect local Codex context, preview configuration changes, and verify them against a fresh task. Native SwiftUI; local processing. Early source-build release.
https://github.com/evilstar2016/codex-context-bar

## Show HN 标题与首评

Title: Show HN: Codex Context Bar – a native macOS inspector for Codex context

Comment:
I built this to make context-related configuration easier to inspect and verify. It separates what was saved from what a new task actually reports, and keeps unknown evidence explicit. Everything is processed locally by a Swift/SwiftUI app. Cost figures are estimates based on static reference rates, not billing data. It is early and currently built from source; I’d especially appreciate feedback on compatibility and the preview/verification workflow.

## 配图与发布注意

首图建议使用 `docs/design/workbench-light.png`，详情配图使用 `docs/design/inspector-light.png`。它们使用合成数据。不要使用包含真实项目路径、会话正文或账号信息的截图。

避免宣称“官方工具”“精确账单”“保证省 X%”“支持所有 Codex 版本”或“已公证一键安装”。当前实现不支持这些表述。
