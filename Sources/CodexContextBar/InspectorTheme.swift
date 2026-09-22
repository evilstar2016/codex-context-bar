import SwiftUI

/// Native dark inspector palette, shared by the window, sheets, and menu extra.
enum InspectorTheme {
    static let background = Color(red: 0.105, green: 0.117, blue: 0.124)
    static let toolbar = Color(red: 0.137, green: 0.149, blue: 0.157)
    static let raised = Color(red: 0.165, green: 0.180, blue: 0.188)
    static let line = Color.white.opacity(0.13)
    static let text = Color(red: 0.94, green: 0.95, blue: 0.95)
    static let secondary = Color(red: 0.68, green: 0.71, blue: 0.73)
    static let teal = Color(red: 0.20, green: 0.60, blue: 0.61)
    static let button = Color(red: 36.0 / 255, green: 120.0 / 255, blue: 123.0 / 255)
    static let selection = Color(red: 0.12, green: 0.25, blue: 0.27)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.35)
    static let observed = Color(red: 0.39, green: 0.78, blue: 0.67)
}

struct InspectorButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: prominent ? 16 : 14, weight: prominent ? .semibold : .regular))
            .foregroundStyle(InspectorTheme.text)
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
