import AppKit
import ApplicationServices
import CryptoKit

let appPath = CommandLine.arguments[1]
let runtime = CommandLine.arguments[2]
let arch = ProcessInfo.processInfo.environment["ARCH"]!
func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }
func get(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
}
func match(_ element: AXUIElement, _ value: String, _ depth: Int = 0) -> AXUIElement? {
    if ["AXIdentifier", "AXTitle", "AXValue", "AXDescription"].contains(where: { (get(element, $0) as? String) == value }) { return element }
    if depth < 18 {
        for child in get(element, "AXChildren") as? [AXUIElement] ?? [] {
            if let found = match(child, value, depth + 1) { return found }
        }
    }
    return nil
}
func wait(_ value: String, excluding: pid_t = 0) -> (AXUIElement, pid_t) {
    for _ in 0..<240 {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == appPath && $0.processIdentifier != excluding }),
           let found = match(AXUIElementCreateApplication(app.processIdentifier), value) { return (found, app.processIdentifier) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }
    fail("Visible native control not found: " + value)
}
func capture(_ name: String) {
    if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == appPath }) {
        app.activate(options: [.activateIgnoringOtherApps])
    }
    // AX controls are available before the native alert's opening animation ends.
    RunLoop.current.run(until: Date().addingTimeInterval(1.0))
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "evidence/" + name + ".png"]
    do { try process.run(); process.waitUntilExit() } catch { fail("Screenshot unavailable") }
    if process.terminationStatus != 0 { fail("Native screenshot failed") }
}
func press(_ element: AXUIElement) {
    if AXUIElementPerformAction(element, kAXPressAction as CFString) != .success { fail("Native button rejected press") }
}
func json(_ path: String) -> [String: Any] {
    return (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)))) as? [String: Any] ?? [:]
}
guard AXIsProcessTrusted() else { fail("Runner lacks native Accessibility permission") }
let (_, oldPid) = wait("macOS 0.5.4-alpha.5")
let (badge, _) = wait("update-notice")
let position = get(badge, "AXPosition")
let size = get(badge, "AXSize")
guard let position = position, let size = size else { fail("No badge geometry") }
var point = CGPoint.zero
var dimensions = CGSize.zero
guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
      AXValueGetValue(size as! AXValue, .cgSize, &dimensions), dimensions.width > 0 else { fail("Invalid badge geometry") }
capture("01-previous-version-automatic-badge")
press(badge)
let (download, _) = wait("Continue")
capture("02-download-confirmation")
press(download)
RunLoop.current.run(until: Date().addingTimeInterval(0.3))
capture("03-native-download-progress")
_ = wait("Restart the companion to install the verified update? Codex stays open.")
let (install, _) = wait("Continue")
capture("04-verified-install-confirmation")
let state = json(runtime + "/updates/state.json")
guard state["ready"] as? Bool == true, state["current"] as? String == "0.5.4-alpha.5", state["version"] as? String == "0.6.0-alpha.1" else { fail("Wrong download state") }
guard let bytes = try? Data(contentsOf: URL(fileURLWithPath: runtime + "/updates/update.dmg")) else { fail("No downloaded DMG") }
let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
let name = "AI-Usage-Monitor-macOS-0.6.0-alpha.1-" + arch + "-unsigned-test.dmg"
let assets = json("evidence/target-release.json")["assets"] as? [[String: Any]] ?? []
guard assets.first(where: { $0["name"] as? String == name })?["digest"] as? String == "sha256:" + digest else { fail("Downloaded DMG differs from public release") }
press(install)
let (_, newPid) = wait("macOS 0.6.0-alpha.1", excluding: oldPid)
capture("05-restarted-new-version")
var complete = false
for _ in 0..<60 {
    if json(runtime + "/updates/transaction.json")["stage"] as? String == "complete" { complete = true; break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
}
let transaction = json(runtime + "/updates/transaction.json")
let ack = json(runtime + "/updates/ack.json")
guard complete, transaction["settingsPreserved"] as? Bool == true,
      ack["stage"] as? String == "app-ready", ack["version"] as? String == "0.6.0-alpha.1",
      ack["bundlePath"] as? String == appPath else { fail("New app acknowledgement or installation transaction incomplete") }
guard let bundle = Bundle(path: appPath), bundle.object(forInfoDictionaryKey: "CQSReleaseVersion") as? String == "0.6.0-alpha.1" else { fail("Installed bundle has wrong version") }
let report: [String: Any] = ["passed": true, "architecture": arch, "oldVersion": "0.5.4-alpha.5", "newVersion": "0.6.0-alpha.1", "oldPid": oldPid, "newPid": newPid, "nativeAutomaticBadge": true, "badgeX": point.x, "badgeY": point.y, "downloadedDmgSha256": digest, "downloadMatchesPublicRelease": true, "settingsPreserved": true, "installationComplete": true, "newAppAcknowledged": true, "source": "Public previous DMG and production signed feed; no mocks", "completedAt": ISO8601DateFormatter().string(from: Date())]
do { try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "evidence/result.json")) } catch { fail("Cannot save evidence report") }
print("PASS native public upgrade " + arch)
