# Codex Context Bar 标识

概念：上下文括号包住三条递减横线，表示上下文整理与 Token 节省。

- AppLogo.png：彩色应用 Logo，深石墨底、薄荷青符号、透明外边缘。
- MenuBarIcon.svg：可编辑的单色矢量图，18 × 18 pt。
- MenuBarIcon.pdf：供原生 macOS 使用的 18 × 18 pt 矢量图。
- MenuBarIcon.png、MenuBarIcon@2x.png、MenuBarIcon@3x.png：透明黑色模板图，分别为 18、36、54 px。
- MenuBarPreview.png：深浅背景预览，包含放大与 18pt 原尺寸。

菜单栏接入时将图像设为 template（NSImage.isTemplate = true），显示尺寸设为 18 × 18 pt，由系统适配颜色。不要把预览图用于菜单栏。

已接入应用：菜单栏从 Swift 资源包加载 MenuBarIcon.pdf，按 18pt template 模式显示。
发布构建脚本从 AppLogo.png 生成标准尺寸的 AppIcon.icns，Info.plist 指定其为应用图标。
修改菜单栏 PDF 时，同时更新 Sources/CodexContextBar/Resources/MenuBarIcon.pdf；应用图标只需更新本目录的 AppLogo.png 并重新构建。
