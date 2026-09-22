import AppKit
import SwiftUI

/// Keep the blur at full strength; only the graphite backing changes opacity.
struct GlassBackground: View {
    @AppStorage("glassTransparency") private var transparency = 0.65
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            FrostedWindowMaterial(scheme: colorScheme)
            InspectorTheme.background.opacity(reduceTransparency ? 1 : 1 - min(max(transparency, 0), 0.85) * 0.45)
            LinearGradient(colors: [.white.opacity(reduceTransparency ? 0 : 0.045), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FrostedWindowMaterial: NSViewRepresentable {
    let scheme: ColorScheme
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = WindowMaterialView()
        view.material = .sidebar
        view.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    }

    private final class WindowMaterialView: NSVisualEffectView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isOpaque = false
            window?.backgroundColor = .clear
            window?.titlebarAppearsTransparent = true
        }
    }
}

struct GlassAppearanceControl: View {
    @State private var showingAppearance = false

    var body: some View {
        Button { showingAppearance.toggle() } label: {
            Image(systemName: "circle.lefthalf.filled")
        }
        .buttonStyle(.plain)
        .help("调整玻璃透明度")
        .accessibilityLabel("外观与透明度")
        .popover(isPresented: $showingAppearance) { GlassAppearancePanel() }
    }
}

struct GlassAppearancePanel: View {
    @AppStorage("glassTransparency") private var transparency = 0.65
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("磨砂玻璃").font(.headline)
            HStack {
                Text("背景透明度")
                Spacer()
                Text("\(Int((transparency * 100).rounded()))%")
                    .monospacedDigit().foregroundStyle(InspectorTheme.secondary)
            }
            Slider(value: $transparency, in: 0...0.85)
                .accessibilityLabel("背景透明度")
                .accessibilityValue("\(Int((transparency * 100).rounded()))%")
                .disabled(reduceTransparency)
            HStack {
                Text("实色")
                Spacer()
                Text("更通透")
            }.font(.caption).foregroundStyle(InspectorTheme.secondary)
            Text(reduceTransparency ? "系统已开启“减少透明度”，当前使用实色背景。" : "跟随系统明暗主题。通透度即时保存，并保留可读底色；文字与按钮不透明。")
                .font(.caption).foregroundStyle(InspectorTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("恢复默认") { transparency = 0.65 }
        }
        .padding(22).frame(width: 290)
        .foregroundStyle(InspectorTheme.text)
        .background { GlassBackground() }

        .tint(InspectorTheme.teal)
    }
}
