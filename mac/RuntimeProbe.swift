import Foundation
import Darwin

final class RuntimeProbe {
    enum Outcome: Equatable { case ready, missing, failed, timedOut }
    private var process: Process?
    private var timer: Timer?
    private var completed = false
    private var completion: ((Outcome) -> Void)?

    func run(_ executable: URL, arguments: [String] = ["--version"], timeout: TimeInterval = 20, completion: @escaping (Outcome) -> Void) {
        self.completion = completion
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { finish(.missing); return }
        let child = Process(), output = Pipe()
        child.executableURL = executable; child.arguments = arguments
        child.standardOutput = output; child.standardError = FileHandle.nullDevice
        process = child
        child.terminationHandler = { [weak self] child in
            DispatchQueue.main.async {
                guard let self = self, !self.completed else { return }
                let bytes = output.fileHandleForReading.readDataToEndOfFile()
                let version = String(data: bytes.prefix(256), encoding: .utf8) ?? ""
                self.finish(child.terminationStatus == 0 && version.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+\s*$"#, options: .regularExpression) != nil ? .ready : .failed)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.cancelProcess(); self?.finish(.timedOut)
        }
        do { try child.run() } catch { finish(.failed) }
    }
    func cancel() { cancelProcess(); finish(.failed) }
    private func cancelProcess() {
        guard let child = process, child.isRunning else { return }
        child.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
        }
    }
    private func finish(_ outcome: Outcome) {
        guard !completed else { return }; completed = true; timer?.invalidate(); timer = nil
        let callback = completion; completion = nil; callback?(outcome)
    }
}
