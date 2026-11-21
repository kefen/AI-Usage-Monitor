import Foundation
import Darwin

enum Bootstrap {
    static var releaseVersion: String? {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CQSReleaseVersion") as? String, !version.isEmpty { return version }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("payload/versions.json"),
              let data = try? Data(contentsOf: url), let versions = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return versions["macos"] as? String
    }
    // Called only after installation and native window initialization, before plan detection.
    @discardableResult static func acknowledgeUpdate(at root: URL, arguments: [String], version: String?, bundleURL: URL) throws -> Bool {
        func argument(_ flag: String) -> String? {
            guard arguments.filter({ $0 == flag }).count == 1, let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        let fm = FileManager.default
        let updates = root.appendingPathComponent(".runtime/updates")
        let transaction = updates.appendingPathComponent("transaction.json")
        guard let supplied = argument("--update-transaction"), supplied == transaction.path,
              let version = version, argument("--update-version") == version else { return false }
        for url in [root, root.appendingPathComponent(".runtime"), updates, transaction, updates.appendingPathComponent("ack.json")] {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { return false }
        }
        guard fm.fileExists(atPath: transaction.path),
              let value = try JSONSerialization.jsonObject(with: Data(contentsOf: transaction)) as? [String: Any],
              value["schema"] as? Int == 1, value["stage"] as? String == "launching",
              let id = value["id"] as? String, UUID(uuidString: id) != nil,
              value["version"] as? String == version,
              let destination = value["destination"] as? String, destination.hasPrefix("/"),
              URL(fileURLWithPath: destination).resolvingSymlinksInPath().standardizedFileURL.path == bundleURL.resolvingSymlinksInPath().standardizedFileURL.path else { return false }
        let ack: [String: Any] = ["id": id, "stage": "app-ready", "version": version, "bundlePath": bundleURL.path]
        try JSONSerialization.data(withJSONObject: ack, options: [.sortedKeys]).write(to: updates.appendingPathComponent("ack.json"), options: .atomic)
        return true
    }
    static func install(at root: URL) throws {
        let fm = FileManager.default
        guard let payload = Bundle.main.resourceURL?.appendingPathComponent("payload"), fm.fileExists(atPath: payload.path) else { return }
        let marker = root.appendingPathComponent("versions.json")
        let packagedVersion = try Data(contentsOf: payload.appendingPathComponent("versions.json"))
        for path in [root, root.appendingPathComponent(".runtime")] {
            if (try? path.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw NSError(domain: "CQS", code: 3, userInfo: [NSLocalizedDescriptionKey: "Linked installation folders are not supported."])
            }
        }
        if let installedVersion = try? Data(contentsOf: marker), installedVersion == packagedVersion,
           fm.isExecutableFile(atPath: root.appendingPathComponent("runtime/node").path) { return }
        let lock = root.appendingPathComponent(".runtime/mac.pid")
        if let text = try? String(contentsOf: lock, encoding: .utf8), let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1, kill(pid, 0) == 0 {
            throw NSError(domain: "CQS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Exit the previous AI Usage Monitor before installing this update."])
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
