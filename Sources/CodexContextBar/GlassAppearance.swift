import AppKit
import SwiftUI

enum AppTheme: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Native window blur stays opaque to interaction; the slider adjusts its tinted backing.
struct GlassBackground: View {
    @AppStorage("glassTransparency") private var transparency = 0.85
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                FrostedWindowMaterial(scheme: colorScheme)
                Color(nsColor: .windowBackgroundColor)
                    .opacity(1 - min(max(transparency, 0), 1))
                LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.06 : 0.22), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
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
        view.material = .underWindowBackground
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
    var showsTitle = false
    @State private var showingAppearance = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        Button { showingAppearance.toggle() } label: {
            if showsTitle {
                Label(language.text("磨砂玻璃"), systemImage: "circle.lefthalf.filled")
                    .font(.system(size: 12))
            } else {
                Image(systemName: "circle.lefthalf.filled")
            }
        }
        .buttonStyle(.plain)
        .help(language.text("调整玻璃透明度"))
        .accessibilityLabel(language.text("外观与透明度"))
        .popover(isPresented: $showingAppearance) { GlassAppearancePanel() }
    }
}

struct GlassAppearancePanel: View {
    @AppStorage("glassTransparency") private var transparency = 0.85
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("磨砂玻璃")).font(.headline)
            HStack {
                Text(language.text("背景透明度"))
                Spacer()
                Text("\(Int((transparency * 100).rounded()))%")
                    .monospacedDigit().foregroundStyle(InspectorTheme.secondary)
            }
            Slider(value: $transparency, in: 0...1)
                .accessibilityLabel(language.text("背景透明度"))
                .accessibilityValue("\(Int((transparency * 100).rounded()))%")
                .disabled(reduceTransparency)
            HStack {
                Text(language.text("实色"))
                Spacer()
                Text(language.text("更通透"))
            }.font(.caption).foregroundStyle(InspectorTheme.secondary)
            Text(language.text(reduceTransparency ? "系统已开启“减少透明度”，当前使用实色背景。" : "通透度即时保存。100% 移除底色，保留系统模糊；文字与按钮不透明。"))
                .font(.caption).foregroundStyle(InspectorTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(language.text("恢复默认")) { transparency = 0.85 }
        }
        .padding(22).frame(width: 290)
        .foregroundStyle(InspectorTheme.text)
        .background { GlassBackground() }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(reduceTransparency ? 0 : 0.18), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .tint(InspectorTheme.teal)
    }
}
