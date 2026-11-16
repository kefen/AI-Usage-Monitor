import Foundation
import Darwin

enum Bootstrap {
    static func install(at root: URL) throws {
        let fm = FileManager.default
        guard let payload = Bundle.main.resourceURL?.appendingPathComponent("payload"), fm.fileExists(atPath: payload.path) else { return }
        let marker = root.appendingPathComponent("versions.json")
        if (try? Data(contentsOf: marker)) == (try? Data(contentsOf: payload.appendingPathComponent("versions.json"))) { return }
        let lock = root.appendingPathComponent(".runtime/mac.pid")
        if let text = try? String(contentsOf: lock, encoding: .utf8), let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1, kill(pid, 0) == 0 {
            throw NSError(domain: "CQS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Exit the previous Codex Quota Sidebar before installing this update."])
        }
        let parent = root.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let stage = parent.appendingPathComponent("CodexSidebarMeter-stage-" + UUID().uuidString)
        let backup = parent.appendingPathComponent("CodexSidebarMeter-backup-" + UUID().uuidString)
        try fm.copyItem(at: payload, to: stage)
        let state = root.appendingPathComponent(".runtime")
        if fm.fileExists(atPath: state.path) { try fm.copyItem(at: state, to: stage.appendingPathComponent(".runtime")) }
        let hadRoot = fm.fileExists(atPath: root.path)
        if hadRoot { try fm.moveItem(at: root, to: backup) }
        do { try fm.moveItem(at: stage, to: root) }
        catch { if hadRoot { try? fm.moveItem(at: backup, to: root) }; throw error }
    }
}
