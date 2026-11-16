import Foundation

enum MetricPresentation {
    static func count(_ value: Double) -> String {
        guard value.isFinite, value >= 0, value.rounded() == value, value <= 9007199254740991 else { return "--" }
        if value >= 1_000_000_000 { return String(format: "%.2fB", locale: Locale(identifier: "en_US_POSIX"), value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", locale: Locale(identifier: "en_US_POSIX"), value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", locale: Locale(identifier: "en_US_POSIX"), value / 1_000) }
        return String(format: "%.0f", value)
    }
}
