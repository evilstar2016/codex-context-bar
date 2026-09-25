import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    func text(_ key: String) -> String {
        guard self == .english else { return key }
        let symlinkPrefix = "配置路径包含符号链接，请使用真实目录："
        if key.hasPrefix(symlinkPrefix) {
            return "The configuration path contains a symlink; use the real folder: " + String(key.dropFirst(symlinkPrefix.count))
        }
        guard
              let path = Bundle.module.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .chinese
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
