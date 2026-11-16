import Foundation

@main struct MetricPresentationTest {
    static func main() {
        precondition(MetricPresentation.count(0) == "0")
        precondition(MetricPresentation.count(1234) == "1.2K")
        precondition(MetricPresentation.count(202600000) == "202.6M")
        precondition(MetricPresentation.count(3008200000) == "3.01B")
        for value in [-1.0, Double.infinity, Double.nan, 1.5, 9007199254740992] {
            precondition(MetricPresentation.count(value) == "--")
        }
        print("PASS: compact count units and invalid values")
    }
}
