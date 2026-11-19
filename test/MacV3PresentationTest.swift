import Foundation

@main struct MacV3PresentationTest {
    static func main() {
        precondition(MetricPresentation.strictBoolean(true) == true)
        precondition(MetricPresentation.strictBoolean(false) == false)
        for invalid in [1, 0, "true", "false", NSNull()] as [Any] {
            precondition(MetricPresentation.strictBoolean(invalid) == nil)
        }
        precondition(MetricPresentation.strictBoolean(nil) == nil)
        let booleanJSON = try! JSONSerialization.jsonObject(with: Data("{\"available\":false,\"numeric\":1}".utf8)) as! [String: Any]
        precondition(MetricPresentation.strictBoolean(booleanJSON["available"]) == false)
        precondition(MetricPresentation.strictBoolean(booleanJSON["numeric"]) == nil)
        for code in MetricPresentation.updateFailureReasons.keys {
            precondition(MetricPresentation.updateFailureCode(["error": code]) == code)
        }
        precondition(MetricPresentation.updateFailureCode(["error": "https://private.invalid/secret"]) == nil)
        precondition(MetricPresentation.updateFailureCode(["error": "E_UPDATE_NEW_UNKNOWN"]) == nil)
        precondition(MetricPresentation.updateFailureCode(["available": false]) == nil)
        precondition(MetricPresentation.updateFailureCode(["available": true]) == nil)
        precondition(MetricPresentation.persistedUpdateFailureCode(["stage": "check-failed", "updatedAt": 101, "code": "E_UPDATE_NETWORK"], since: 100) == "E_UPDATE_NETWORK")
        precondition(MetricPresentation.persistedUpdateFailureCode(["stage": "check-failed", "updatedAt": 99, "code": "E_UPDATE_NETWORK"], since: 100) == nil)
        precondition(MetricPresentation.persistedUpdateFailureCode(["stage": "complete", "updatedAt": 101, "code": "E_UPDATE_NETWORK"], since: 100) == nil)
        let now = 1_795_000_000_000.0
        let snapshot: [String: Any] = ["generatedAt": now, "quotaAt": now, "usageAt": now,
            "windows": [["minutes": 300, "remaining": 0, "resetsAt": now + 3600000], ["minutes": 10080, "remaining": 37]],
            "daily": ["date": "2026-11-17", "value": 202650000], "monthAverage": 125350000,
            "week": 0, "lifetime": 3010000000, "creditBalance": "0", "resetCredits": 0]
        let all = MetricPresentation.overview(snapshot, display: [:], member: [:], connected: true, now: now)
        precondition(all.count == 12)
        precondition(all["monthly"]?.value == "--")
        let future = now + 3600000
        precondition(MetricPresentation.resetMilliseconds(future / 1000) == future)
        precondition(MetricPresentation.resetMilliseconds(future) == future)
        for invalid in [0, -1, true, "1795003600", Double.nan, Double.infinity, Double.greatestFiniteMagnitude, NSNull()] as [Any] {
            precondition(MetricPresentation.resetMilliseconds(invalid) == nil)
        }
        var seconds = snapshot
        seconds["windows"] = [["minutes": 300, "remaining": 0, "resetsAt": future / 1000]]
        let secondsReset = MetricPresentation.overview(seconds, display: [:], member: [:], connected: true, now: now)["reset"]!
        precondition(secondsReset.value != "--" && secondsReset.value == all["reset"]?.value)
        seconds["windows"] = [["resetsAt": (now + 7200000) / 1000], ["resetsAt": future], ["resetsAt": (now - 1000) / 1000]]
        precondition(MetricPresentation.overview(seconds, display: [:], member: [:], connected: true, now: now)["reset"]?.value == secondsReset.value)
        seconds["windows"] = [["resetsAt": now / 1000], ["resetsAt": now - 1000]]
        precondition(MetricPresentation.overview(seconds, display: [:], member: [:], connected: true, now: now)["reset"]?.value == "--")
        precondition(MetricPresentation.overview(snapshot, display: [:], member: [:], connected: false, now: now)["reset"]?.value == "--")
        precondition(MetricPresentation.overview(snapshot, display: [:], member: [:], connected: true, now: now + 180001)["reset"]?.value == "--")
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
        // Estimates must win over a stale previously entered manual expiry.
        precondition(MetricPresentation.renewal(["enabled": true, "purchaseDate": "2026-01-31", "date": "2026-12-01", "monthlyEstimate": true]) == "2026-02-28")
        precondition(MetricPresentation.renewal(["enabled": true, "purchaseDate": "2024-02-29", "annualEstimate": true]) == "2025-02-28")
        precondition(MetricPresentation.renewal(["enabled": true, "date": "2026-12-01", "monthlyEstimate": true]) == nil)
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
        print("PASS: V3 all twelve, choices, zeros, blank dates and common plot scale")
    }
}
