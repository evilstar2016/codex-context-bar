# Repository instructions

- Keep the product native Swift/SwiftUI. Do not introduce Node, a web frontend, or an HTTP server.
- Use `ContextCore` for testable parsing and configuration logic; keep filesystem work out of SwiftUI views.
- Treat session logs as untrusted data. Only complete initial metadata can support absence claims.
- A saved configuration is pending, never runtime-verified without fresh matching session evidence.
- Never modify the developer's real Codex configuration during tests. Use temporary roots and synthetic logs.
- Preserve unrelated configuration, detect stale previews, and restore only operation-owned keys.
- Do not commit transcripts, credentials, user configuration, local operation records, or build products.
- Run `swift test`, `scripts/build-app.sh`, and `git diff --check` before submitting changes.
- Keep changes small and document observation limits without inventing exact token or billing savings.
