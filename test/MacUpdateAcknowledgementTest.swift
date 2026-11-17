import Foundation

@main struct MacUpdateAcknowledgementTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let updates = root.appendingPathComponent(".runtime/updates")
        try FileManager.default.createDirectory(at: updates, withIntermediateDirectories: true)
        let bundle = root.appendingPathComponent("Companion.app")
        let transaction = updates.appendingPathComponent("transaction.json")
        let id = UUID().uuidString
        let version = "0.5.0-alpha.1"
        let value: [String: Any] = ["schema": 1, "id": id, "stage": "launching", "version": version, "destination": bundle.path]
        try JSONSerialization.data(withJSONObject: value).write(to: transaction)
        let args = ["app", "--update-transaction", transaction.path, "--update-version", version]
        let wrongVersion = try Bootstrap.acknowledgeUpdate(at: root, arguments: args, version: "0.5.0", bundleURL: bundle)
        precondition(!wrongVersion)
        precondition(!FileManager.default.fileExists(atPath: updates.appendingPathComponent("ack.json").path))
        let accepted = try Bootstrap.acknowledgeUpdate(at: root, arguments: args, version: version, bundleURL: bundle)
        precondition(accepted)
        let ack = try JSONSerialization.jsonObject(with: Data(contentsOf: updates.appendingPathComponent("ack.json"))) as! [String: Any]
        precondition(ack["id"] as? String == id && ack["stage"] as? String == "app-ready")
        precondition(ack["version"] as? String == version && ack["bundlePath"] as? String == bundle.path)
        let wrongPath = try Bootstrap.acknowledgeUpdate(at: root, arguments: ["app", "--update-transaction", root.appendingPathComponent("other.json").path, "--update-version", version], version: version, bundleURL: bundle)
        let wrongBundle = try Bootstrap.acknowledgeUpdate(at: root, arguments: args, version: version, bundleURL: root.appendingPathComponent("Wrong.app"))
        precondition(!wrongPath && !wrongBundle)
        for field in ["id", "stage", "version", "schema"] {
            var invalid = value; invalid[field] = "invalid"
            try JSONSerialization.data(withJSONObject: invalid).write(to: transaction)
            let rejected = try Bootstrap.acknowledgeUpdate(at: root, arguments: args, version: version, bundleURL: bundle)
            precondition(!rejected)
        }
        try JSONSerialization.data(withJSONObject: value).write(to: transaction)
        let settings = root.appendingPathComponent(".runtime/membership.json")
        let original = Data(#"{"purchaseDate":"2020-01-31","futureKey":"preserved"}"#.utf8)
        try original.write(to: settings)
        let acknowledged = try Bootstrap.acknowledgeUpdate(at: root, arguments: args, version: version, bundleURL: bundle)
        let retained = try Data(contentsOf: settings)
        precondition(acknowledged && retained == original)
        try FileManager.default.removeItem(at: updates.appendingPathComponent("ack.json"))
        let outside = root.appendingPathComponent("outside.json")
        try FileManager.default.createSymbolicLink(at: updates.appendingPathComponent("ack.json"), withDestinationURL: outside)
        let linked = try Bootstrap.acknowledgeUpdate(at: root, arguments: args, version: version, bundleURL: bundle)
        precondition(!linked && !FileManager.default.fileExists(atPath: outside.path))
        print("PASS: acknowledgement path, transaction ID, full version provenance and bundle destination")
    }
}
