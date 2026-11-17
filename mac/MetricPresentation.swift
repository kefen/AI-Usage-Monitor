import Foundation
import CoreFoundation

struct MetricDatum {
    var value = "--"
    var caption = "Not returned"
    var fraction: Double? = nil
}

enum MetricPresentation {
    static func strictBoolean(_ value: Any?) -> Bool? {
        guard let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return value.boolValue
    }
    static let updateFailureReasons = [
        "E_UPDATE_NETWORK": "Cannot reach the update server. Check your connection and try again.",
        "E_UPDATE_SIGNATURE": "The update signature could not be verified. No update was installed.",
        "E_UPDATE_CHECKSUM": "The update file failed verification. No update was installed.",
        "E_UPDATE_CONFIGURATION": "Update configuration could not be read. Check the installation and try again.",
        "E_UPDATE_METADATA": "Update information is invalid or unavailable. Try again later.",
        "E_UPDATE_APP_STILL_RUNNING": "The old companion is still running. The update was not installed.",
        "E_UPDATE_INSTALL_LOCATION": "Reopen the companion from Applications before updating.",
        "E_UPDATE_BUNDLE_VERSION": "The downloaded app version does not match the verified update.",
        "E_UPDATE_LAUNCH_UNVERIFIED": "The updated app did not pass launch verification.",
        "E_UPDATE_WORKER_NOT_READY": "The update worker is not ready. The companion will stay open.",
        "E_UPDATE_HANDSHAKE_TIMEOUT": "Update verification timed out. The companion will stay open."
    ]
    static func updateFailureCode(_ result: [String: Any]?) -> String? {
        guard let code = result?["error"] as? String, updateFailureReasons[code] != nil else { return nil }
        return code
    }
    static func persistedUpdateFailureCode(_ record: [String: Any], since started: Double) -> String? {
        guard record["stage"] as? String == "check-failed", let stamp = number(record["updatedAt"]), stamp >= started,
              let code = record["code"] as? String else { return nil }
        return updateFailureCode(["error": code])
    }
    static let keys = ["plan", "renewal", "short", "week", "reset", "resetCredits", "credits", "daily", "average", "weekly", "lifetime"]
    static func recordDate(_ text: String?) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let text = text, let date = f.date(from: text), f.string(from: date) == text else { return nil }
        return date
    }
    static func renewal(_ member: [String: Any]) -> String? {
        guard member["enabled"] as? Bool == true else { return nil }
        let estimated = member["monthlyEstimate"] as? Bool == true || member["annualEstimate"] as? Bool == true
        if !estimated, let text = member["date"] as? String, recordDate(text) != nil { return text }
        guard let start = recordDate(member["purchaseDate"] as? String), member["monthlyEstimate"] as? Bool == true || member["annualEstimate"] as? Bool == true else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        guard let end = calendar.date(byAdding: member["annualEstimate"] as? Bool == true ? .year : .month, value: 1, to: start) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: end)
    }
    static func plotMaximum(_ values: [Double]) -> Double {
        let largest = values.filter { $0.isFinite && $0 >= 0 }.max() ?? 0
        guard largest > 0 else { return 1_000_000 }
        let unit = pow(10, floor(log10(largest)))
        return ceil(largest / unit / 0.5) * unit * 0.5
    }
    static func resetMilliseconds(_ raw: Any?) -> Double? {
        guard let value = number(raw), value > 0 else { return nil }
        // Core timestamps are seconds; also accept millisecond snapshots, as on Windows.
        let milliseconds = value < 100_000_000_000 ? value * 1000 : value
        guard milliseconds.isFinite, milliseconds < 253_402_300_800_000 else { return nil }
        return milliseconds
    }
    static func overview(_ snapshot: [String: Any], display: [String: Any], member: [String: Any], connected: Bool, now: Double) -> [String: MetricDatum] {
        let base = values(snapshot, connected: connected, now: now)
        var result = Dictionary(uniqueKeysWithValues: zip(["short", "week", "daily", "weekly", "lifetime", "average"], base))
        let missing = base[0].caption.isEmpty ? "Not returned" : base[0].caption
        for key in ["reset", "resetCredits", "credits"] { result[key] = MetricDatum(caption: missing) }
        let freshQuota = connected && number(snapshot["generatedAt"]).map { now >= $0 && now - $0 < 90000 } == true && number(snapshot["quotaAt"]).map { now >= $0 && now - $0 < 180000 } == true
        if freshQuota {
            let windows = snapshot["windows"] as? [[String: Any]] ?? []
            if let stamp = windows.compactMap({ resetMilliseconds($0["resetsAt"]) }).filter({ $0 > now }).min() {
                let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
                result["reset"] = MetricDatum(value: f.string(from: Date(timeIntervalSince1970: stamp / 1000)), caption: "")
            }
            if let n = number(snapshot["resetCredits"]), count(n) != "--" { result["resetCredits"] = MetricDatum(value: count(n), caption: "") }
            if let text = snapshot["creditBalance"] as? String, text.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil, let n = Double(text), n.isFinite, n <= 9007199254740991 {
                result["credits"] = MetricDatum(value: count(floor(n)), caption: "")
            }
        }
        let plan = member["plan"] as? String ?? ""
        let names = ["free": "Free", "go": "Go", "plus": "Plus", "pro": "Pro", "business": "Business", "enterprise": "Enterprise", "edu": "Edu", "other": "Other / unknown"]
        result["plan"] = MetricDatum(value: names[plan] ?? "--", caption: names[plan] == nil ? "Not set" : member["planSource"] as? String == "desktop" ? "Desktop detection" : "Manual record (locked)")
        result["renewal"] = MetricDatum(value: renewal(member) ?? "--", caption: renewal(member) == nil ? "Not set" : member["estimated"] as? Bool == true ? "Estimated date" : "Manual date")
        return result.filter { display[$0.key] as? Bool != false }
    }
    static func count(_ value: Double) -> String {
        guard value.isFinite, value >= 0, value.rounded() == value, value <= 9007199254740991 else { return "--" }
        for (scale, suffix) in [(1_000_000_000.0, "B"), (1_000_000.0, "M"), (1_000.0, "K")] where value >= scale {
            return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value / scale).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression) + suffix
        }
        return String(format: "%.0f", value)
    }
    static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite, value.doubleValue >= 0 else { return nil }
        return value.doubleValue
    }
    static func values(_ snapshot: [String:Any], connected: Bool, now: Double) -> [MetricDatum] {
        func fresh(_ key: String, _ age: Double) -> Bool { guard let n = number(snapshot[key]) else { return false }; return now >= n && now - n < age }
        let caption = !connected ? "Not connected" : number(snapshot["generatedAt"]) != nil && !fresh("generatedAt",90000) ? "Data expired" : "Not returned"
        var result = Array(repeating: MetricDatum(caption: caption), count: 6)
        guard connected, fresh("generatedAt",90000) else { return result }
        if fresh("quotaAt",180000) {
            let windows = snapshot["windows"] as? [[String:Any]] ?? []
            for (i, minutes) in [(0,300),(1,10080)] {
                let matches = windows.filter { number($0["minutes"]) == Double(minutes) }
                if matches.count == 1, let value = number(matches[0]["remaining"]), value <= 100 {
                    result[i] = MetricDatum(value: String(format: "%g%%", value), caption: "", fraction: value / 100)
                }
            }
        } else if number(snapshot["quotaAt"]) != nil { result[0].caption = "Data expired"; result[1].caption = "Data expired" }
        if fresh("usageAt",5400000) {
            let daily = snapshot["daily"] as? [String:Any] ?? [:]
            for (i, raw) in [(2,daily["value"]),(3,snapshot["week"]),(4,snapshot["lifetime"]),(5,snapshot["monthAverage"])] {
                if let n = number(raw), count(n) != "--" { result[i] = MetricDatum(value: count(n), caption: "") }
            }
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
            if let text = daily["date"] as? String, let day = f.date(from: text), f.string(from: day) == text, result[2].value != "--" {
                let today = Date(timeIntervalSince1970: now / 1000)
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
                result[2].caption = text == f.string(from: yesterday) ? "Yesterday" : text == f.string(from: today) ? "Today" : text
            } else { result[2] = MetricDatum() }
        } else if number(snapshot["usageAt"]) != nil { for i in 2..<6 { result[i].caption = "Data expired" } }
        return result
    }
}
