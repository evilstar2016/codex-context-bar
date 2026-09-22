import AppKit
import SwiftUI

/// Native dark inspector palette, shared by the window, sheets, and menu extra.
enum InspectorTheme {
    private static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
    static let background = adaptive(NSColor(white: 0.98, alpha: 1), NSColor(white: 0.10, alpha: 1))
    static let toolbar = background
    static let raised = adaptive(NSColor(white: 0.89, alpha: 1), NSColor(white: 0.19, alpha: 1))
    static let line = adaptive(NSColor(white: 0, alpha: 0.16), NSColor(white: 1, alpha: 0.16))
    static let text = adaptive(NSColor(white: 0.10, alpha: 1), NSColor(white: 0.96, alpha: 1))
    static let secondary = adaptive(NSColor(white: 0.30, alpha: 1), NSColor(white: 0.78, alpha: 1))
    static let teal = adaptive(NSColor(red: 0.04, green: 0.39, blue: 0.40, alpha: 1), NSColor(red: 0.35, green: 0.78, blue: 0.78, alpha: 1))
    static let button = Color(red: 36.0 / 255, green: 120.0 / 255, blue: 123.0 / 255)
    static let selection = adaptive(NSColor(red: 0.79, green: 0.90, blue: 0.90, alpha: 1), NSColor(red: 0.12, green: 0.25, blue: 0.27, alpha: 1))
    static let amber = adaptive(NSColor(red: 0.48, green: 0.27, blue: 0.01, alpha: 1), NSColor(red: 1, green: 0.74, blue: 0.35, alpha: 1))
    static let observed = adaptive(NSColor(red: 0.02, green: 0.39, blue: 0.30, alpha: 1), NSColor(red: 0.39, green: 0.78, blue: 0.67, alpha: 1))
}

struct InspectorButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: prominent ? 16 : 14, weight: prominent ? .semibold : .regular))
            .foregroundStyle(prominent ? Color.white : InspectorTheme.text)
            .frame(maxWidth: .infinity, minHeight: prominent ? 46 : 40)
            .background(prominent ? InspectorTheme.button : InspectorTheme.raised,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(prominent ? 0.2 : 0.09)))
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.75 : 1)
    }
}

struct InspectorDivider: View {
    var body: some View { Rectangle().fill(InspectorTheme.line).frame(height: 1).accessibilityHidden(true) }
}

struct StatusLabel: View {
    let text: String
    let color: Color
    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "circle.fill").font(.system(size: 8))
        }
        .foregroundStyle(color)
    }
}
