import Foundation

@main
struct RuntimeProbeTest {
    static func main() {
        func check(_ file: String, _ args: [String], _ expected: RuntimeProbe.Outcome, timeout: TimeInterval = 1) {
            let probe = RuntimeProbe(); var result: RuntimeProbe.Outcome?
            probe.run(URL(fileURLWithPath: file), arguments: args, timeout: timeout) { result = $0 }
            let deadline = Date().addingTimeInterval(4)
            while result == nil && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
            precondition(result == expected, "Unexpected runtime outcome for " + file)
        }
        check("/bin/echo", ["v24.16.0"], .ready)
        check("/bin/echo", ["not a runtime"], .failed)
        check("/usr/bin/false", [], .failed)
        check("/definitely-not-installed-cqs-node", [], .missing)
        check("/bin/sleep", ["10"], .timedOut, timeout: 0.1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        print("PASS: runtime ready, invalid output, launch failure, missing file and timeout")
    }
}
