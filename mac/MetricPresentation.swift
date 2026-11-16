import Foundation
import CoreFoundation

struct MetricDatum {
    var value = "--"
    var caption = "Not returned"
    var fraction: Double? = nil
}

enum MetricPresentation {
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
