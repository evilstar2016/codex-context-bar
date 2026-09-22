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
