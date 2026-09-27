# Contributing / 参与贡献

感谢你帮助改进 Codex Context Bar。欢迎使用中文或英文提交 Issue 和 Pull Request。

## 报告问题

请提供 macOS 版本、芯片架构、应用 commit、Codex runtime 版本（如可获得）、复现步骤、预期与实际结果。截图请隐藏用户名、项目路径、任务内容等个人信息。

不要上传真实会话 JSONL、登录凭据、完整配置或本地操作记录。尽量构造最小合成样本。发现可能暴露敏感信息的问题时，不要在公开 Issue 中粘贴敏感数据。

## 提交改动

1. Fork 仓库并创建独立分支。
2. 保持 Swift / SwiftUI 原生实现；可测试的逻辑放在 `Sources/ContextCore`。
3. 使用临时目录与合成日志测试，不读写真实 `~/.codex` 配置。
4. 运行以下检查，在 PR 中说明行为变化、验证结果与兼容边界；UI 改动附合成数据截图。

```sh
swift test
./scripts/build-app.sh
git diff --check
```

配置已保存不能等同于运行时已生效；证据不足不能等同于零成本或未注入。修改配置时必须保留无关键、检查过期预览，并保持撤销只恢复本次目标键。

## English

Issues and pull requests are welcome in Chinese or English. Include macOS, architecture, app commit, runtime version if available, reproduction steps, and expected versus actual behavior. Use synthetic fixtures and redact screenshots. Never upload real transcripts, credentials, full configuration or operation records.

Keep the app native Swift/SwiftUI and put testable logic in ContextCore. Tests must use temporary directories, never real Codex configuration. Run the commands above before submitting. UI changes should include synthetic-data screenshots. Preserve the distinction between saved configuration and observed runtime evidence, and never treat missing evidence as zero cost or absence.
