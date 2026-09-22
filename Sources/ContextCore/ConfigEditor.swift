import Foundation
import TOMLDecoder

/// Edits only conventional [table] boolean keys. Full TOML parsing validates both
/// documents, and a semantic comparison rejects accidental edits inside strings.
public enum ConfigEditor {
    public static func value(in text: String, target: ControlTarget) throws -> Bool? {
        let table = try TOMLTable(source: text)
        guard table.contains(key: target.table) else { return nil }
        let child = try table.table(forKey: target.table)
        guard child.contains(key: target.key) else { return nil }
        return try child.bool(forKey: target.key)
    }

    public static func edit(_ text: String, target: ControlTarget, value: Bool?) throws -> String {
        var expected = try Dictionary<String, Any>(TOMLTable(source: text))
        var section = expected[target.table] as? [String: Any] ?? [:]
        if expected[target.table] != nil && !(expected[target.table] is [String: Any]) {
            throw ContextError.message("目标配置不是 TOML table")
        }
        if let value { section[target.key] = value } else { section.removeValue(forKey: target.key) }
        expected[target.table] = section
        var lines = text.components(separatedBy: "\n")
        let tablePattern = "^\\s*\\[" + target.table + "\\]\\s*(?:#.*)?$"
        let starts = lines.indices.filter { matches(lines[$0], tablePattern) }
        guard starts.count <= 1 else { throw ContextError.message("不支持重复 table") }
        let assignment = value.map { "\(target.key) = \($0)" }
        if let start = starts.first {
            let end = lines.indices.first { $0 > start && matches(lines[$0], "^\\s*\\[") } ?? lines.count
            let keys = lines.indices.filter { $0 > start && $0 < end && matches(lines[$0], "^\\s*" + target.key + "\\s*=") }
            guard keys.count <= 1 else { throw ContextError.message("目标键重复") }
            if let index = keys.first {
                guard matches(lines[index], "^\\s*" + target.key + "\\s*=\\s*(true|false)\\s*(?:#.*)?$") else {
                    throw ContextError.message("目标键不是简单布尔值；请手动编辑")
                }
                if let value {
                    let regex = try NSRegularExpression(pattern: "(=\\s*)(true|false)")
                    let range = NSRange(lines[index].startIndex..., in: lines[index])
                    lines[index] = regex.stringByReplacingMatches(in: lines[index], range: range,
                        withTemplate: "$1" + String(value))
                } else if let comment = lines[index].firstIndex(of: "#") {
                    lines[index] = String(lines[index][comment...])
                } else { lines.remove(at: index) }
            } else if let assignment { lines.insert(assignment, at: end) }
        } else {
            if !lines.last!.isEmpty { lines.append("") }
            lines.append("[\(target.table)]")
            if let assignment { lines.append(assignment) }
            lines.append("")
        }
        let result = lines.joined(separator: "\n")
        let actual = try Dictionary<String, Any>(TOMLTable(source: result))
        guard canonical(actual) == canonical(expected) else {
            throw ContextError.message("此 TOML 布局无法安全局部修改（可能使用点号、inline table 或多行字符串）；文件未修改")
        }
        return result
    }

    private static func matches(_ string: String, _ pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }

    private static func canonical(_ value: Any) -> String {
        if let object = value as? [String: Any] {
            return "{" + object.keys.sorted().map { String(reflecting: $0) + ":" + canonical(object[$0]!) }.joined(separator: ",") + "}"
        }
        if let array = value as? [Any] { return "[" + array.map(canonical).joined(separator: ",") + "]" }
        return String(reflecting: type(of: value)) + ":" + String(reflecting: value)
    }
}
