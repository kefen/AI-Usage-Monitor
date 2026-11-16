import Foundation

@main struct MetricPresentationTest {
    static func main() {
        precondition(MetricPresentation.count(0) == "0")
        precondition(MetricPresentation.count(1234) == "1.23K")
        precondition(MetricPresentation.count(202600000) == "202.6M")
        precondition(MetricPresentation.count(3008200000) == "3.01B")
        let now = Date().timeIntervalSince1970 * 1000
        let data: [String:Any] = ["generatedAt":now,"quotaAt":now,"usageAt":now,"windows":[["minutes":10080,"remaining":37]],"monthAverage":0,"lifetime":3008200000]
        let values = MetricPresentation.values(data, connected:true, now:now)
        precondition(values.count == 6 && values[1].value == "37%" && values[5].value == "0")
        precondition(values[0].caption == "Not returned" && values[3].caption == "Not returned")
        precondition(MetricPresentation.values(data, connected:false, now:now).allSatisfy { $0.value == "--" && $0.caption == "Not connected" })
        precondition(MetricPresentation.values(data, connected:true, now:now+90001).allSatisfy { $0.caption == "Data expired" })
        for value in [-1.0, Double.infinity, Double.nan, 1.5, 9007199254740992] {
            precondition(MetricPresentation.count(value) == "--")
        }
        print("PASS: compact count units and invalid values")
    }
}
