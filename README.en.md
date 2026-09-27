<p align="center">
  <img src="Resources/Branding/AppLogo.png" width="112" alt="Codex Context Bar logo">
</p>

# Codex Context Bar

**Understand your Codex context before you trim it.**

[简体中文](README.md) · [Contributing](CONTRIBUTING.md)

A native macOS menu bar app for **Codex**. Inspect context instructions in local session logs, estimate historical usage and potential savings, preview configuration changes, and check the results against a fresh task.

An independent community project, not affiliated with or endorsed by OpenAI. This is an early version intended for source builds.

![Project overview](docs/design/workbench-light.png)

*Screenshots use synthetic data. Displayed amounts are illustrative API-equivalent estimates, not subscription charges.*

## What it does

- Inspects skill catalog, memory, plugin and other context instructions, with approximate token counts.
- Summarizes the current project or all projects over rolling 7-day and 30-day windows.
- Defaults to simulation using `gpt-6-astra`, the highest ordinary-input rate in the bundled reference table. A discreet link switches to the actual model recorded for each response. Rates are static reference data, not live-verified prices.
- Previews configuration diffs and scope before saving. Keeps saved state separate from fresh-task verification, and supports undoing the target key.
- Processes data locally. The running app does not connect to the network, upload sessions or read login credentials. Building downloads dependencies.
- Uses native SwiftUI, Chinese/English UI, system/light/dark themes, and adjustable frosted glass from 0–100% (85% by default).

## Build and run

Requires macOS 14+ and Swift 6.0+ (Xcode 16+). Builds have been verified on Apple Silicon with Xcode 26.2 / Swift 6.2.3. The script builds for the host architecture; Intel has not been validated.

```sh
git clone https://github.com/evilstar2016/codex-context-bar.git
cd codex-context-bar
swift test
./scripts/build-app.sh
open 'build/Codex Context Bar.app'
```

You can also open `Package.swift` in Xcode. Launch the app from its macOS menu bar icon. Builds use local ad-hoc signing; there is currently no Developer ID-notarized distribution or automatic updater.

## Workflow

1. Select the project directory you use in Codex.
2. Expand an instruction category and review the impact of changing it.
3. Preview the target file, configuration key and scope, then save if appropriate.
4. Create a **new local task in Codex Desktop in the same directory**.
5. Check new records for matching evidence. Undo the change if needed.

Verification requires a complete new session header after the change, with matching directory and source. A fork, another worktree or an existing session is not equivalent. The all-projects view is a summary; return to the current project to edit configuration.

The default data directory is `~/.codex`. `CODEX_HOME` and a folder selected in Settings are supported. Finder launches may not inherit shell environment variables.

| Control | Scope | Impact |
| --- | --- | --- |
| Automatic skill catalog | Current project | May reduce automatic skill discovery; explicitly selected skills may still appear |
| Memory | User-wide, affecting new tasks in other projects | Stops memory instruction injection; does not delete memory files |
| Plugins | User-wide, affecting new tasks in other projects | Affects plugin functionality, not just recommendations |

Plugin recommendations remain read-only. Other configuration layers or the host may override saved settings.

## Estimates and compatibility

Amounts are **API-equivalent estimates, not subscription bills, actual charges or promised savings**. Response usage comes from logs; instruction token counts approximate UTF-8 byte length and are not exact tokenizer output. Savings ranges reflect uncertainty about cache attribution. They do not model cache rebuilding, output changes or lost functionality.

The bundled rates come from reference data dated 2026-09-07 and are not live official OpenAI pricing. Unknown models, invalid usage and missing evidence remain unknown. Detailed formulas and limitations are documented in [Chinese](docs/ESTIMATION.md).

Compatibility is based on investigation of runtime `0.154.0-alpha.6.2`; other versions require observation. Missing metadata, inherited history and truncated or unrecognized logs cannot prove absence. A verified header describes that task, not every request or definitive causation.

## Privacy and contributions

Configuration is written only after an explicit save from a preview. Local operation records contain paths, original target-key values, timestamps and fingerprints, not full configuration or transcripts. Undo preserves unrelated edits. Records live under `~/Library/Application Support/CodexContextBar/operations/`.

Please report reproducible issues and contribute synthetic compatibility fixtures, translations or focused fixes. Never upload real sessions, credentials or personal configuration. See [CONTRIBUTING.md](CONTRIBUTING.md). Tests use temporary directories and synthetic logs; offscreen snapshots verify layout, not live desktop blur or full GUI interaction.

```sh
swift test
./scripts/build-app.sh
git diff --check
```

Future work includes precise tokenization, more compatibility fixtures, file-event-based scanning and signed/notarized releases.

## Credits and license

Historical cost analysis follows the approach used by Skill Doctor. TOML parsing uses [TOMLDecoder](https://github.com/dduan/TOMLDecoder); see [third-party notices](THIRD_PARTY_NOTICES.md). Released under the [MIT License](LICENSE).
