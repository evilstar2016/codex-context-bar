# Design QA — dark native inspector

Source visual truth: `docs/design/selected-inspector.png` (the exact user-selected generated image).
Implementation: actual SwiftUI `Dashboard`, `MenuContent`, and preview sheet rendered with NSHostingView into PNG files using synthetic data. No real transcript or configuration is captured.

## Comparison history

1. Initial native render (`docs/design/qa-initial-inspector.png`, 2096×1572 pixels, 1048×786 points at 2×): source and render opened together. [P2] Right panel expanded to 480pt instead of approximately 420pt, reducing the list width. [P2] Compact-height evidence disclosure crowded the fixed footer. Fixed the inspector maximum width at 420pt and added height-aware spacing; rendered again at 1× for direct comparison.
2. Second render: source and 1048×786 / 316×356 / 880×640 snapshots opened together. Panel proportions, row heights, headings and compact controls are now readable. [P2] Primary action and evidence section sit too high relative to the source; adjusted detail-row spacing and vertical gaps. [P2] White button label contrast on the mock-inspired teal was only about 3:1; darkened the button teal while retaining the accent color, reaching approximately 4.6:1. Final comparison confirms both fixes.

## Scope and normalization

Source: 1488×1058 image containing a desktop, a native window, and a menu popover. The app-owned main content is approximately 1048×786 at x48/y132; the menu is approximately 316×356 at x1144/y34. Compare these content regions with actual 1× native-view renders; wallpaper, desktop menu bar, traffic lights and OS window shadows are system-owned and are not painted by the app. Native window toolbar styling needs a live app check in addition to content snapshots.

State: selected skill catalog, saved false, older complete header still containing the catalog, new-task verification pending. `所选观测` replaces `上次观测` to remain accurate when the user selects an older session. Character totals include all actual fixture blocks rather than copying the generated mock's incomplete arithmetic.

## Required fidelity surfaces

- Fonts/typography: SF system font with native Chinese fallback, 30pt primary heading, 25pt inspector heading, 14–15pt body, 11–13pt supporting text; verified in final side-by-side comparison.
- Spacing/layout: six/four split, 64pt table rows, 30pt outer list margin, height-aware inspector spacing; verified in final side-by-side comparison.
- Colors/tokens: graphite base, teal selection and button, amber pending state, muted secondary labels; contrast adjusted as described above.
- Assets: all app icons use SF Symbols. The source's desktop wallpaper is not an application asset. No raster art is required inside either product surface.
- Copy/content: historical observation and saved configuration remain distinct; recommendation block stays read-only; project/user scope and consequences appear before writing.

## Interaction verification

Core and view-model tests cover selection, absent/unknown state, scope boundaries, preview without writes, pending/changed status, operation counting, stale previews, undo and fresh-session verification. No real Codex config was edited. The native app connection was retried and timed out (Computer Use -10005). A live mouse/keyboard walkthrough and native titlebar capture remain unverified; no claim of full end-to-end GUI coverage is made.

## Final comparison

Selected source and final actual-view captures were opened in the same tool call. Main content matches the selected hierarchy, split, row rhythm, graphite/teal palette and action placement. Smaller system body typography is retained for native density. Button teal is deliberately darker for contrast. No unresolved P0/P1/P2 findings within rendered app content. Configuration consequences and long paths were also expanded vertically after detecting truncation, then rendered and inspected again.

Evidence: `docs/design/inspector.png`, `menu.png`, `inspector-compact.png`, `recommendations.png`, `empty.png`, `config-preview.png`. Main 1048×786, compact 880×640, menu 316×356, preview 570×540. All 25 isolated Swift tests pass, including native snapshot rendering. The snapshots are synthetic fixtures, not live user-session captures.

final result: passed (app-content visual QA and automated state verification). Live native toolbar/menu interaction QA is not completed because the capture connection times out.

## Frosted-glass update

Window, menu panel and sheets now use NSVisualEffectView with behind-window blending. The persistent 0–85% slider adjusts graphite backing opacity, leaving text and controls opaque. Reduce Transparency forces a solid backing. Offscreen snapshots validate layout only: WindowServer background blur requires an on-screen window and is not proven by bitmap rendering. The earlier opaque screenshots document the previous design.

## Session selection and layout correction

Removed the duplicate toolbar title; moved project and session labels into a persistent content bar to prevent macOS icon-only toolbar compression. Default selection prefers complete headers. Incomplete records expose the reason and an action to select complete evidence; unknown totals no longer display zero. Valid partial block observations remain visible. Compact 880×640 content snapshots checked; native window chrome still requires live verification.

## Light appearance and data-source correction

Verified separate Aqua/Dark Aqua native snapshots for both inspector and menu. Semantic dynamic colors replace fixed white labels; material appearance follows SwiftUI color scheme. Backing opacity retains a readability floor. Invalid data directories are rejected before persisting, and missing-session warnings remain visible in empty states. Real read-only scan of the correct local source returned 30 sessions, three complete, with 10,769 characters in the default complete header. No transcript content was captured or committed. Offscreen captures cannot prove desktop compositing.


## 2026-09-26 — selected layout 1, native Apple appearance

Current source of truth supersedes the earlier dark dashboard: `docs/design/selected-apple-workbench.png`, refined from the user's selected layout 1 and shown before implementation. Actual content captures use isolated synthetic fixtures; no customer data or real configuration was changed.

### Comparison and iterations

1. Opened the selected visual and first light, dark and compact English native renders together in one comparison input. [P2] The approved logo did not resolve through SwiftUI's named image initializer; load the bundled PNG explicitly through NSImage. [P2] The expanded row's background was too close to the main surface; use a subtle semantic selection tint. Both fixes were applied.
2. Re-rendered and compared source, final light and final dark captures together. Logo and expanded-row hierarchy are now visible. Checked pending, no-data, welcome, menu and configuration-preview states. Compact English content intentionally scrolls beneath a fixed footer; headings wrap into a vertical summary instead of clipping. Native inactive-window buttons are gray in offscreen captures; active-window accent and WindowServer material require live verification.

### Normalization and fidelity

Source is 1448×1086 pixels including a generated window frame and surrounding shadow. Compare its interior hierarchy to the 1048×786-point native content render; no wallpaper, shadow or traffic lights are painted into application content. Compact English capture is 880×640. Captures use Aqua/Dark Aqua explicitly, selected skill catalog, project scope, 30 days, maximum-model pricing, and synthetic priced-response data. Pending and no-data captures use separately labeled states.

- Fonts: native system font and Chinese fallback; 26pt main title, 32pt amount, 17pt section headings, 13–15pt controls/body, 11–12pt metadata. Native content density deliberately replaces the generated visual's oversized text.
- Spacing: 200pt sidebar, 54pt context toolbar, 30pt content inset, 24pt sections, 8pt row radius, bottom-pinned local-analysis footer. The summary stacks when horizontal space is insufficient.
- Colors: semantic white/gray macOS surfaces, secondary labels and separator colors; restrained adaptive teal for amounts and evidence links, amber only for pending/attention states. System appearance and Reduce Transparency remain supported.
- Assets: previously approved bundled AppLogo.png, existing template menubar icon, SF Symbols for functional icons. No new decorative imagery.
- Copy: a single scoped potential-savings amount, explicit API-estimate/coverage context, discreet actual-model switch. Impact text and project/global scope precede preview. Saved configuration is never called verified until fresh evidence arrives. Unknown data stays unknown.

### Functional verification

47 Swift tests pass, including defaults/scope/time/pricing selection, preview without navigation or writes, read-only all-project summary, evidence navigation, pending menu routing, configuration fingerprints, undo and new-task evidence. Native content snapshots cover light/dark, compact English, all projects, no data, welcome and pending states. Source and final implementation were inspected together, not from memory.

Evidence: `docs/design/workbench-light.png`, `workbench-dark.png`, `workbench-compact-en.png`, `workbench-all.png`, `workbench-no-data.png`, `workbench-welcome.png`, `workbench-pending.png`.

final result: passed for native app-content layout and automated state verification. Live mouse/keyboard, active-window control coloring and compositor blur remain unverified: the native Computer Use connection previously timed out (-10005). This is not a claim of completed end-to-end GUI validation.


## 2026-09-27 — unify session details with the workbench

Compared the actual workbench-light and updated inspector light/dark/compact renders in the same tool response. The user's screenshot identified oversized titlebar controls, dense boxed rows and excessive detail-panel spacing. The inspector now uses the main screen's semantic surfaces, 26pt heading, 13–14pt body, 54pt context toolbar, subtle 8pt selection radius and restrained teal icons. Back navigation comes first; refresh and a single More menu replace the separate titlebar appearance/language menus. Both pages use WorkbenchSettings. Native compact actions replace full-width custom buttons.

Iteration: English Configuration label broke mid-word at 880×640; widened English state labels and re-rendered. The shared settings snapshot needed explicit semantic foreground/background; corrected and visually verified. Main screenshots are 1048×786, compact snapshots 880×640, shared settings 340×310, synthetic fixtures only. Both appearance modes, compact English labels and settings contents were inspected. The snapshot harness formats dates using its Chinese locale; production follows the app/system locale.

47 tests, release app build and git diff --check passed. No configuration semantics changed. final result: passed for app-content visual checks; live mouse/keyboard and window-chrome interaction remain unverified. Evidence: inspector-light.png, inspector.png, inspector-compact.png, inspector-compact-en.png and shared-settings.png under docs/design.
