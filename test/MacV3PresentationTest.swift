import Foundation

@main struct MacV3PresentationTest {
    static func main() {
        let now = 1_795_000_000_000.0
        let snapshot: [String: Any] = ["generatedAt": now, "quotaAt": now, "usageAt": now,
            "windows": [["minutes": 300, "remaining": 0, "resetsAt": now + 3600000], ["minutes": 10080, "remaining": 37]],
            "daily": ["date": "2026-11-17", "value": 202650000], "monthAverage": 125350000,
            "week": 0, "lifetime": 3010000000, "creditBalance": "0", "resetCredits": 0]
        let all = MetricPresentation.overview(snapshot, display: [:], member: [:], connected: true, now: now)
        precondition(all.count == 11)
        precondition(all["short"]?.value == "0%" && all["weekly"]?.value == "0")
        precondition(all["credits"]?.value == "0" && all["resetCredits"]?.value == "0")
        precondition(all["renewal"]?.caption == "Not set")
        precondition(MetricPresentation.overview(snapshot, display: ["short": false], member: [:], connected: true, now: now)["short"] == nil)
        let none = Dictionary(uniqueKeysWithValues: MetricPresentation.keys.map { ($0, false) })
        precondition(MetricPresentation.overview(snapshot, display: none, member: [:], connected: true, now: now).isEmpty)
        precondition(MetricPresentation.overview([:], display: [:], member: [:], connected: true, now: now)["credits"]?.value == "--")
        precondition(MetricPresentation.recordDate(nil) == nil)
        precondition(MetricPresentation.recordDate("2026-02-30") == nil)
        let member: [String: Any] = ["enabled": true, "purchaseDate": "2026-01-31", "monthlyEstimate": true]
        precondition(MetricPresentation.renewal(member) == "2026-02-28")
        precondition(MetricPresentation.renewal(["enabled": true, "monthlyEstimate": true]) == nil)
        precondition(MetricPresentation.plotMaximum([0, 202650000, 125350000]) >= 202650000)
        var fractional = snapshot; fractional["creditBalance"] = "162.9"
        precondition(MetricPresentation.overview(fractional, display: [:], member: [:], connected: true, now: now)["credits"]?.value == "162")
        let legacy = MetricPresentation.overview(snapshot, display: [:], member: ["plan": "pro"], connected: true, now: now)
        precondition(legacy["plan"]?.caption == "Manual record (locked)")
        let disconnected = MetricPresentation.overview(snapshot, display: [:], member: [:], connected: false, now: now)
        precondition(disconnected["short"]?.caption == "Not connected" && disconnected["credits"]?.value == "--")
        let expired = MetricPresentation.overview(snapshot, display: [:], member: [:], connected: true, now: now + 90001)
        precondition(expired["resetCredits"]?.caption == "Data expired")
        print("PASS: V3 all eleven, choices, zeros, blank dates and common plot scale")
    }
}
