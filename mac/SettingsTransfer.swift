import Foundation
import CoreFoundation

enum SettingsTransfer {
    static let files = ["display.json", "membership.json", "language.json"]
    static func checked(_ data: Data) throws -> [String: Any] {
        func invalid() -> NSError { NSError(domain: "CQS", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid settings backup."]) }
        guard data.count <= 65536, let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(root.keys).isSubset(of: Set(files)) else { throw invalid() }
        func boolean(_ value: Any) -> Bool { guard let n = value as? NSNumber else { return false }; return CFGetTypeID(n) == CFBooleanGetTypeID() }
        if let value = root["language.json"] { guard let lang = value as? String, ["en", "zh-CN", "zh-TW"].contains(lang) else { throw invalid() } }
        if let value = root["display.json"] {
            let keys = Set(["plan", "short", "week", "reset", "renewal", "daily", "average", "weekly", "lifetime"])
            guard let display = value as? [String: Any], Set(display.keys).isSubset(of: keys), display.values.allSatisfy(boolean) else { throw invalid() }
        }
        if let value = root["membership.json"] {
            let flags = Set(["enabled", "monthlyEstimate", "annualEstimate", "estimated"])
            let keys = flags.union(["plan", "tier", "purchaseDate", "date", "kind"])
            guard let member = value as? [String: Any], Set(member.keys).isSubset(of: keys) else { throw invalid() }
            for (key, val) in member {
                if flags.contains(key) { guard boolean(val) else { throw invalid() }; continue }
                guard let text = val as? String else { throw invalid() }
                switch key {
                case "plan": guard ["plus", "pro", "business", "enterprise", "edu", "free", "go", "other"].contains(text) else { throw invalid() }
                case "tier": guard ["", "unknown", "100", "200", "500", "standard", "premium"].contains(text) else { throw invalid() }
                case "kind": guard ["renewal", "expiry"].contains(text) else { throw invalid() }
                default:
                    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
                    guard let date = f.date(from: text), f.string(from: date) == text else { throw invalid() }
                }
            }
            if let purchase = member["purchaseDate"] as? String, let date = member["date"] as? String, date < purchase { throw invalid() }
        }
        return root
    }
    static func exportData(_ root: URL) throws -> Data {
        var values: [String: Any] = [:]
        for name in files {
            let url = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { values[name] = try JSONSerialization.jsonObject(with: Data(contentsOf: url), options: [.fragmentsAllowed]) }
        }
        let data = try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]); _ = try checked(data); return data
    }
    static func restore(_ data: Data, at root: URL) throws {
        let values = try checked(data)
        var originals: [String: Data] = [:], changed: [String] = []
        for name in values.keys {
            let url = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { originals[name] = try Data(contentsOf: url) }
        }
        do {
            for (name, value) in values {
                try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]).write(to: root.appendingPathComponent(name), options: .atomic); changed.append(name)
            }
        } catch {
            for name in changed { if let old = originals[name] { try? old.write(to: root.appendingPathComponent(name), options: .atomic) } else { try? FileManager.default.removeItem(at: root.appendingPathComponent(name)) } }
            throw error
        }
    }
}
