import AppKit
import SwiftUI

/// Semantic macOS surfaces with a restrained teal accent.
enum InspectorTheme {
    private static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
    static let background = Color(nsColor: .textBackgroundColor)
    static let toolbar = background
    static let raised = Color(nsColor: .windowBackgroundColor)
    static let line = Color(nsColor: .separatorColor)
    static let text = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let teal = adaptive(NSColor(red: 0.04, green: 0.39, blue: 0.40, alpha: 1), NSColor(red: 0.35, green: 0.78, blue: 0.78, alpha: 1))
    static let button = Color(red: 36.0 / 255, green: 120.0 / 255, blue: 123.0 / 255)
    static let selection = Color(nsColor: .quaternaryLabelColor)
    static let amber = adaptive(NSColor(red: 0.48, green: 0.27, blue: 0.01, alpha: 1), NSColor(red: 1, green: 0.74, blue: 0.35, alpha: 1))
    static let observed = adaptive(NSColor(red: 0.02, green: 0.39, blue: 0.30, alpha: 1), NSColor(red: 0.39, green: 0.78, blue: 0.67, alpha: 1))
}

struct InspectorButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: prominent ? 14 : 13, weight: prominent ? .semibold : .regular))
            .foregroundStyle(prominent ? Color.white : InspectorTheme.text)
            .frame(maxWidth: .infinity, minHeight: prominent ? 34 : 30)
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
