import AppKit

final class FlatButton: NSButton {
    override var intrinsicContentSize: NSSize {
        let size = (title as NSString).size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 13)])
        return NSSize(width: size.width + 28, height: 36)
    }
    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted { NSColor.labelColor.withAlphaComponent(0.06).setFill(); NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill() }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 13), .foregroundColor: isEnabled ? (contentTintColor ?? .labelColor) : NSColor.disabledControlTextColor, .paragraphStyle: paragraph]
        let height = (title as NSString).size(withAttributes: attributes).height
        (title as NSString).draw(in: NSRect(x: 12, y: (bounds.height - height) / 2, width: bounds.width - 24, height: height), withAttributes: attributes)
    }
}

// Native shell only. The shared Node core remains responsible for quota data.
final class QuotaTrack: NSView {
    var fraction: Double? { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.88, alpha: 1).setFill(); bounds.fill()
        if let value = fraction { NSColor(calibratedRed: 0.14, green: 0.58, blue: 0.43, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: bounds.width * value, height: bounds.height).fill() }
    }
}

final class QuotaApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let root = CommandLine.arguments.contains("--ui-smoke") ? FileManager.default.temporaryDirectory.appendingPathComponent("cqs-ui-test-" + UUID().uuidString) : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexSidebarMeter")
    var runtime: URL { root.appendingPathComponent(".runtime") }
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var body = NSStackView()
    var headline = NSTextField(labelWithString: CqsLocale.t("Connecting"))
    var detail = NSTextField(wrappingLabelWithString: CqsLocale.t("Waiting for client and data."))
    var rows: [NSTextField] = []
    var displayChecks: [(String, NSButton)] = []
    var page = ""
    var navigationButtons: [(String, NSButton)] = []
    var restartApproved = false
    var restartButton: NSButton?
    var dirty = false
    var editingReady = false
    var saveButton: NSButton?
    func beginPage(_ next: String) -> Bool {
        if page == next { present(); return false }
        if dirty {
            if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: unexpected unsaved changes before \(next)\n", stderr); exit(1) }
            let dialog = NSAlert(); dialog.messageText = CqsLocale.t("Discard unsaved changes?")
            dialog.addButton(withTitle: CqsLocale.t("Cancel")); dialog.addButton(withTitle: CqsLocale.t("Continue"))
            guard dialog.runModal() == .alertSecondButtonReturn else { return false }
        }
        dirty = false; editingReady = false; saveButton = nil; page = next; body.spacing = 14
        for (key, control) in navigationButtons {
            control.layer?.backgroundColor = (key == next ? NSColor(calibratedRed: 0.90, green: 0.93, blue: 1, alpha: 1) : .clear).cgColor
            control.contentTintColor = key == next ? green : .secondaryLabelColor
        }
        clear(); return true
    }
    @objc func markDirty() { if editingReady { dirty = true } }
    func saved() {
        dirty = false
        guard let control = saveButton else { return }
        control.title = CqsLocale.t("Saved successfully"); control.layer?.backgroundColor = NSColor.white.cgColor; control.layer?.borderWidth = 1; control.contentTintColor = .labelColor; control.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self, weak control] in
            guard let control = control else { return }; control.title = CqsLocale.t("Save"); control.layer?.backgroundColor = self?.green.cgColor; control.layer?.borderWidth = 0; control.contentTintColor = .white; control.isEnabled = true
        }
    }
    var metricFields: [NSTextField] = []
    var metricCaptions: [NSTextField] = []
    var quotaTracks: [QuotaTrack] = []
    let languagePicker = NSPopUpButton()
    var retry: NSButton!
    var updateButton: NSButton!
    var updateProcess: Process?
    var child: Process?
    var log: FileHandle?
    var timer: Timer?
    var stopTimer: Timer?
    var showingSettings = false
    var stopping = false
    var reconnecting = false
    var opening: Process?
    var runtimeProbe: RuntimeProbe?
    var runtimeReady = false
    var runtimeIssue = false
    var runtimeAction: NSButton?
    var feedback = ""
    var feedbackUntil = Date.distantPast
    func notify(_ message: String) { feedback = message; feedbackUntil = Date().addingTimeInterval(10); detail.stringValue = message; present() }
    var stage = "starting"
    var startedAt = Date.distantFuture
    var errorText = ""
    let enabled = NSButton(checkboxWithTitle: CqsLocale.t("Show Codex renewal date"), target: nil, action: nil)
    let plan = NSPopUpButton()
    let purchase = NSDatePicker()
    let mode = NSPopUpButton()
    let next = NSDatePicker()
    let planIDs = ["plus","pro","pro","pro","pro","business","business","business","enterprise","edu","free","go","other"]
    let planTiers = ["","unknown","100","200","500","unknown","standard","premium","","","","",""]
    let green = NSColor(calibratedRed: 0.157, green: 0.392, blue: 0.843, alpha: 1)
    func read(_ name: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: runtime.appendingPathComponent(name)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }
    func write(_ name: String, _ value: [String: Any]) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: runtime.appendingPathComponent(name), options: .atomic)
    }
    func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    func date(_ text: String?) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return text.flatMap { f.date(from: $0) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: launch\n", stderr) }
        guard checkInstallLocation() else { NSApp.terminate(nil); return }
        do { try Bootstrap.install(at: root); try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true) }
        catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        if let languageData = try? JSONSerialization.data(withJSONObject: CqsLocale.language, options: [.fragmentsAllowed]) { try? languageData.write(to: runtime.appendingPathComponent("language.json"), options: .atomic) }
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Codex Quota Sidebar"; window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.contentView!.wantsLayer = true
        window.contentView!.layer?.backgroundColor = NSColor.white.cgColor
        let container = NSStackView(); container.orientation = .vertical; container.alignment = .leading; container.spacing = 14
        container.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        container.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(container)
        NSLayoutConstraint.activate([container.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor), container.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor), container.topAnchor.constraint(equalTo: window.contentView!.topAnchor), container.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)])
        let header = NSStackView(); header.spacing = 16; header.distribution = .fill; header.alignment = .centerY
        header.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let icon = NSImageView(image: NSImage(contentsOf: root.appendingPathComponent("assets/cqs-128.png")) ?? NSImage())
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true; icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let words = NSStackView(); words.orientation = .vertical; words.alignment = .leading; words.spacing = 4
        let title = NSTextField(labelWithString: "Codex Quota Sidebar"); title.font = .systemFont(ofSize: 21, weight: .regular)
        title.identifier = NSUserInterfaceItemIdentifier("brand-title")
        let version = NSTextField(labelWithString: "by KEFEN"); version.textColor = .secondaryLabelColor
        words.addArrangedSubview(title); words.addArrangedSubview(version); header.addArrangedSubview(icon); header.addArrangedSubview(words); container.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        let headerGap = NSView(); header.addArrangedSubview(headerGap); headerGap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerGap.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        header.setVisibilityPriority(.mustHold, for: icon); header.setVisibilityPriority(.mustHold, for: words)
        languagePicker.identifier = NSUserInterfaceItemIdentifier("language")
        languagePicker.addItems(withTitles: ["English", "简体中文", "繁體中文"])
        languagePicker.selectItem(at: CqsLocale.language == "en" ? 0 : CqsLocale.language == "zh-CN" ? 1 : 2)
        languagePicker.target = self; languagePicker.action = #selector(changeLanguage); header.addArrangedSubview(languagePicker)
        let divider = NSBox(); divider.boxType = .separator; container.addArrangedSubview(divider); divider.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        let split = NSView(); split.translatesAutoresizingMaskIntoConstraints = false
        let navigation = NSStackView(); navigation.orientation = .vertical; navigation.alignment = .leading; navigation.spacing = 4
        navigation.wantsLayer = true; navigation.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
        navigation.edgeInsets = NSEdgeInsets(top: 18, left: 12, bottom: 18, right: 12)
        for (key, label, action) in [("overview", "Usage overview", #selector(showStatus)), ("display", "Sidebar content", #selector(showDisplay)), ("subscription", "Codex subscription record", #selector(showSettings)), ("data", "Data and settings", #selector(showData)), ("help", "Diagnostics", #selector(showHelp)), ("about", "About project", #selector(showAbout))] {
            let control = button(label, action); control.alignment = .left
            for constraint in control.constraints where constraint.firstAttribute == .width { constraint.isActive = false }
            control.layer?.borderWidth = 0; control.layer?.backgroundColor = NSColor.clear.cgColor
            control.widthAnchor.constraint(equalToConstant: 181).isActive = true
            navigationButtons.append((key, control)); navigation.addArrangedSubview(control)
        }
        navigation.widthAnchor.constraint(equalToConstant: 205).isActive = true
        navigation.heightAnchor.constraint(greaterThanOrEqualToConstant: 490).isActive = true
        let navigationSpace = NSView(); navigation.addArrangedSubview(navigationSpace)
        navigationSpace.setContentHuggingPriority(.defaultLow, for: .vertical)
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 14; body.distribution = .fill
        body.setContentHuggingPriority(.required, for: .vertical)
        navigation.translatesAutoresizingMaskIntoConstraints = false; body.translatesAutoresizingMaskIntoConstraints = false
        split.addSubview(navigation); split.addSubview(body); container.addArrangedSubview(split)
        NSLayoutConstraint.activate([
            split.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48),
            navigation.leadingAnchor.constraint(equalTo: split.leadingAnchor),
            navigation.topAnchor.constraint(equalTo: split.topAnchor),
            navigation.bottomAnchor.constraint(equalTo: split.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: navigation.trailingAnchor, constant: 28),
            body.trailingAnchor.constraint(equalTo: split.trailingAnchor),
            body.topAnchor.constraint(equalTo: split.topAnchor),
            body.bottomAnchor.constraint(lessThanOrEqualTo: split.bottomAnchor)
        ])
        let spacer = NSView(); container.addArrangedSubview(spacer); spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        let footer = NSStackView(); footer.spacing = 8
        let build = NSTextField(labelWithString: "macOS 0.4.8-alpha.1"); build.textColor = .secondaryLabelColor; build.font = .systemFont(ofSize: 11)
        let updateArea = NSStackView(); updateArea.orientation = .vertical; updateArea.alignment = .leading; updateArea.spacing = 4
        updateButton = button("Check for updates", #selector(checkUpdates)); updateArea.addArrangedSubview(updateButton); updateArea.addArrangedSubview(build)
        footer.addArrangedSubview(updateArea)
        let gap = NSView(); footer.addArrangedSubview(gap); gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        retry = button("Reconnect", #selector(reconnect))
        footer.addArrangedSubview(button("Exit software", #selector(stop))); footer.addArrangedSubview(retry); footer.addArrangedSubview(button("Open Codex", #selector(openCodex), primary: true))
        container.addArrangedSubview(footer); footer.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(contentsOf: root.appendingPathComponent("assets/tray-template.png")) { image.isTemplate = true; image.size = NSSize(width: 18, height: 18); statusItem.button?.image = image }
        statusItem.button?.toolTip = "Codex Quota Sidebar"
        let menu = NSMenu()
        for (text, action) in [(CqsLocale.t("View status"), #selector(showStatus)), (CqsLocale.t("Settings"), #selector(showSettings)), (CqsLocale.t("Sidebar items"), #selector(showDisplay)), (CqsLocale.t("Refresh data"), #selector(refresh)), (CqsLocale.t("Exit software"), #selector(stop))] {
            let item = NSMenuItem(title: text, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: initial overview\n", stderr) }
        showStatus()
        if !CommandLine.arguments.contains("--ui-smoke") { DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.runUpdate("auto") } }
        if !CommandLine.arguments.contains("--ui-smoke") { Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in self?.runUpdate("auto") } }
        if CommandLine.arguments.contains("--ui-smoke") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.smokeTest() }; return
        }
        if read("preferences.json")["cdpConsent"] as? Bool != true {
            let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Allow local debugging"); prompt.informativeText = CqsLocale.t("Debugging grants more than quota access. Other local programs may access the port. Stopping the meter does not close it: fully quit Codex and reopen from its official entry. This is unofficial software. Verify that the CLI and desktop accounts match.")
            prompt.addButton(withTitle: CqsLocale.t("Cancel")); let agree = prompt.addButton(withTitle: CqsLocale.t("Agree and continue")); agree.keyEquivalent = ""
            guard prompt.runModal() == .alertSecondButtonReturn else { NSApp.terminate(nil); return }
            do { var prefs = read("preferences.json"); prefs["cdpConsent"] = true; try write("preferences.json", prefs) }
            catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.tick() }
        if read("preferences.json")["macGuideVersion"] as? String != "0.4.8-alpha.1" { stage = "stopped"; showAuthorizationHelp() }
        else { start() }
    }
    func button(_ title: String, _ action: Selector, primary: Bool = false) -> NSButton {
        let result = FlatButton(title: CqsLocale.t(title), target: self, action: action)
        result.isBordered = false; result.font = .systemFont(ofSize: 13, weight: .regular)
        result.alignment = .center
        result.wantsLayer = true; result.layer?.cornerRadius = 4
        result.layer?.borderWidth = primary ? 0 : 1
        result.layer?.borderColor = NSColor(calibratedWhite: 0.85, alpha: 1).cgColor
        result.layer?.backgroundColor = (primary ? green : .white).cgColor
        result.contentTintColor = primary ? .white : .labelColor
        result.heightAnchor.constraint(equalToConstant: 36).isActive = true
        result.widthAnchor.constraint(greaterThanOrEqualToConstant: max(title == "Save" ? 180 : 108, result.intrinsicContentSize.width + 28)).isActive = true
        return result
    }
    func checkInstallLocation() -> Bool {
        if CommandLine.arguments.contains("--ui-smoke") { return true }
        let path = Bundle.main.bundleURL.path
        let readOnlyVolume = path.hasPrefix("/Volumes/") && !FileManager.default.isWritableFile(atPath: Bundle.main.bundleURL.deletingLastPathComponent().path)
        guard readOnlyVolume || path.contains("/AppTranslocation/") else { return true }
        let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Finish installing the app")
        prompt.informativeText = CqsLocale.t("1. Drag Codex Quota Sidebar.app from the disk image into Applications. Replace the old app if upgrading.\n2. Eject the disk image, then open Codex Quota Sidebar from Finder > Applications.\n3. Keep the app in the Dock for next time. You do not need to open the installer again.")
        prompt.addButton(withTitle: CqsLocale.t("Quit"))
        prompt.addButton(withTitle: CqsLocale.t("Open Applications"))
        NSApp.activate(ignoringOtherApps: true)
        if prompt.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications")) }
        return false
    }
    @objc func revealApplication() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    func smokeTest() {
        do {
            let output = URL(fileURLWithPath: CommandLine.arguments.last!); try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for language in ["en", "zh-CN", "zh-TW"] {
                CqsLocale.language = language; languagePicker.selectItem(at: language == "en" ? 0 : language == "zh-CN" ? 1 : 2)
                for action in [showAuthorizationHelp, showStatus, showDisplay, showSettings, showData, showHelp, showAbout] {
                    fputs("UI smoke: switching page, language \(language)\n", stderr)
                    action(); CqsLocale.apply(window.contentView!); window.contentView!.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                    fputs("UI smoke: laid out \(page)\n", stderr)
                    precondition(abs(body.frame.maxY - body.superview!.bounds.maxY) < 2, "Page content is not top aligned")
                    if page == "subscription" { plan.selectItem(at: 2); enabled.state = .on; updateFields(); save(); precondition(!dirty && page == "subscription" && saveButton?.isEnabled == false) }
                    if page == "display" { saveDisplay(); precondition(!dirty && page == "display") }
                    let view = window.contentView!
                    func findTitle(_ parent: NSView) -> NSView? { if parent.identifier?.rawValue == "brand-title" { return parent }; for child in parent.subviews { if let match = findTitle(child) { return match } }; return nil }
                    guard let brand = findTitle(view), !brand.isHiddenOrHasHiddenAncestor, brand.bounds.width > 150, brand.bounds.height > 10 else { throw NSError(domain: "CQS", code: 4, userInfo: [NSLocalizedDescriptionKey: "Brand header is hidden or clipped"]) }
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(page + "-" + language + ".png"))
                }
                runtimeIssue = true; stage = "failed"; errorText = CqsLocale.t("Node runtime did not start. If macOS blocked node, review Privacy & Security and the installation guide, then reconnect. This does not establish a Codex signature error.") + "\nE_RUNTIME_START"
                showStatus(); tick(); window.contentView!.layoutSubtreeIfNeeded()
                precondition(retry.isEnabled && headline.stringValue == CqsLocale.t("Runtime unavailable"))
                let failedView = window.contentView!, failedBitmap = failedView.bitmapImageRepForCachingDisplay(in: failedView.bounds)!
                failedView.cacheDisplay(in: failedView.bounds, to: failedBitmap)
                try failedBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("runtime-failure-" + language + ".png"))
                runtimeIssue = false; stage = "failed"; errorText = "E_RESTART_REQUIRED"; page = ""
                showStatus(); window.contentView!.layoutSubtreeIfNeeded()
                let restartView = window.contentView!, restartBitmap = restartView.bitmapImageRepForCachingDisplay(in: restartView.bounds)!
                restartView.cacheDisplay(in: restartView.bounds, to: restartBitmap)
                try restartBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("restart-required-" + language + ".png"))
                errorText = "E_CDP_OWNER"; page = ""
                showStatus(); showHelp(); showStatus(); tick(); window.contentView!.layoutSubtreeIfNeeded()
                precondition(abs(body.frame.maxY - body.superview!.bounds.maxY) < 2, "Failure refresh shifted content")
                let ownerView = window.contentView!, ownerBitmap = ownerView.bitmapImageRepForCachingDisplay(in: ownerView.bounds)!
                ownerView.cacheDisplay(in: ownerView.bounds, to: ownerBitmap)
                try ownerBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("owner-failure-" + language + ".png"))
                let now = Date().timeIntervalSince1970 * 1000
                try write("browser-state.json", ["generatedAt": now, "quotaAt": now, "usageAt": now, "windows": [["minutes": 300, "remaining": 75],["minutes": 10080, "remaining": 37]], "daily": ["date": dateString(Calendar.current.date(byAdding: .day, value: -1, to: Date())!), "value": 202650000], "monthAverage":125400000, "week":96900000, "lifetime": 3008200000])
                stage = "mounted"; errorText = ""; page = ""; showStatus(); tick(); window.contentView!.layoutSubtreeIfNeeded()
                rows[1].stringValue = CqsLocale.t("Synced"); rows[2].stringValue = CqsLocale.t("Synced"); rows[3].stringValue = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                precondition(abs(metricFields[2].convert(metricFields[2].bounds, to: window.contentView).minY - metricFields[5].convert(metricFields[5].bounds, to: window.contentView).minY) < 1)
                precondition(abs(metricFields[3].convert(metricFields[3].bounds, to: window.contentView).minY - metricFields[4].convert(metricFields[4].bounds, to: window.contentView).minY) < 1)
                precondition(!metricFields[2].stringValue.contains("\n") && !metricCaptions[2].stringValue.isEmpty)
                precondition(metricFields[4].stringValue == "3.01B" && metricCaptions[2].font!.pointSize < metricFields[2].font!.pointSize)
                let connectedView = window.contentView!, connectedBitmap = connectedView.bitmapImageRepForCachingDisplay(in: connectedView.bounds)!
                connectedView.cacheDisplay(in: connectedView.bounds, to: connectedBitmap)
                try connectedBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("connected-fixture-" + language + ".png"))
                try write("browser-state.json", ["generatedAt": now, "quotaAt": now, "usageAt": now, "windows": []])
                updateMetrics(true); rows[1].stringValue = CqsLocale.t("Not returned"); rows[2].stringValue = CqsLocale.t("Not returned")
                precondition(metricFields.allSatisfy { $0.stringValue == "--" } && metricCaptions.allSatisfy { $0.stringValue == CqsLocale.t("Not returned") })
                let emptyBitmap = connectedView.bitmapImageRepForCachingDisplay(in: connectedView.bounds)!
                connectedView.cacheDisplay(in: connectedView.bounds, to: emptyBitmap)
                try emptyBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("empty-fixture-" + language + ".png"))
                updateMetrics(false); precondition(metricCaptions[2].stringValue == CqsLocale.t("Not connected") && metricFields[2].stringValue == "--")
                stage = "stopped"; errorText = ""; page = ""
            }
            let backup = try SettingsTransfer.exportData(runtime); try SettingsTransfer.restore(backup, at: runtime)
            do { _ = try SettingsTransfer.checked(Data("{\"auth.json\":{\"token\":\"do-not-import\"}}".utf8)); fatalError("Unknown settings accepted") } catch {}
            print("PASS: native Mac pages, three languages, save persistence and settings boundary; synthetic fixture only")
            NSApp.terminate(nil)
        } catch { fputs("UI smoke failed: \(error)\n", stderr); exit(1) }
    }
    func clear() { restartButton = nil; for view in body.arrangedSubviews { body.removeArrangedSubview(view); view.removeFromSuperview() } }
    func present() { CqsLocale.apply(window.contentView!); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func openGitHub() { NSWorkspace.shared.open(CqsLocale.repository) }
    @objc func changeLanguage() {
        CqsLocale.language = ["en","zh-CN","zh-TW"][languagePicker.indexOfSelectedItem]
        UserDefaults.standard.set(CqsLocale.language, forKey: "cqs-language")
        try? Data(("\"" + CqsLocale.language + "\"").utf8).write(to: runtime.appendingPathComponent("language.json"), options: .atomic)
        CqsLocale.apply(window.contentView!)
        for item in statusItem.menu?.items ?? [] { item.title = CqsLocale.t(item.title) }
    }
    func line(_ label: String, _ value: NSView, into target: NSStackView? = nil) {
        let row = NSStackView(); row.spacing = 20; let key = NSTextField(labelWithString: CqsLocale.t(label)); key.textColor = .secondaryLabelColor
        key.font = .systemFont(ofSize: 13, weight: .regular)
        if let field = value as? NSTextField { field.font = .systemFont(ofSize: 13, weight: .regular) }
        key.widthAnchor.constraint(equalToConstant: 130).isActive = true; row.addArrangedSubview(key); row.addArrangedSubview(value); (target ?? body).addArrangedSubview(row)
        if value is NSPopUpButton || value is NSDatePicker { value.widthAnchor.constraint(equalToConstant: 400).isActive = true }
    }
    @objc func showStatus() {
        if page == "overview" { tick(); present(); return }
        guard beginPage("overview") else { return }; showingSettings = false; rows = []
        headline.font = .systemFont(ofSize: 22, weight: .regular); body.addArrangedSubview(headline)
        detail.font = .systemFont(ofSize: 13, weight: .regular); detail.textColor = .secondaryLabelColor; body.addArrangedSubview(detail)
        detail.widthAnchor.constraint(lessThanOrEqualToConstant: 600).isActive = true
        if runtimeIssue { authorizationButtons() }
        if errorText.trimmingCharacters(in: .whitespacesAndNewlines) == "E_RESTART_REQUIRED" {
            restartButton = button("Save work, restart and connect", #selector(confirmRestart), primary: true)
            body.addArrangedSubview(restartButton!)
        }
        body.spacing = 10
        let statusLines = NSStackView(); statusLines.orientation = .horizontal; statusLines.alignment = .top; statusLines.distribution = .fillEqually; statusLines.spacing = 16
        for title in ["Client","Quota data","Token data","Last sync"] {
            let cell = NSStackView(); cell.orientation = .vertical; cell.alignment = .leading; cell.spacing = 4
            let label = NSTextField(labelWithString: CqsLocale.t(title)); label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor
            let field = NSTextField(labelWithString: "--"); field.font = .systemFont(ofSize: 11); field.lineBreakMode = .byTruncatingTail
            cell.addArrangedSubview(label); cell.addArrangedSubview(field); rows.append(field); statusLines.addArrangedSubview(cell)
        }
        body.addArrangedSubview(statusLines); statusLines.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        metricFields = []; metricCaptions = []; quotaTracks = []
        let names = ["5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens","Monthly daily average"]
        var columns: [NSStackView] = []
        for index in 0..<6 {
            let column = NSStackView(); column.orientation = .vertical; column.alignment = .leading; column.spacing = 4
            let name = NSTextField(labelWithString: CqsLocale.t(names[index])); name.font = .systemFont(ofSize: 12); name.textColor = .secondaryLabelColor
            let value = NSTextField(labelWithString: "--"); value.font = .monospacedDigitSystemFont(ofSize: 24, weight: .regular)
            let caption = NSTextField(labelWithString: CqsLocale.t("Not returned")); caption.font = .systemFont(ofSize: 11); caption.textColor = .secondaryLabelColor
            name.heightAnchor.constraint(equalToConstant: 18).isActive = true; value.heightAnchor.constraint(equalToConstant: 34).isActive = true
            caption.heightAnchor.constraint(equalToConstant: 16).isActive = true; caption.lineBreakMode = .byTruncatingTail
            column.addArrangedSubview(name); column.addArrangedSubview(value); column.addArrangedSubview(caption)
            if index < 2 { let track = QuotaTrack(frame: .zero); track.heightAnchor.constraint(equalToConstant: 4).isActive = true; column.addArrangedSubview(track); track.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true; quotaTracks.append(track) }
            columns.append(column); metricFields.append(value); metricCaptions.append(caption)
        }
        for indices in [[0,1],[2,5],[3,4]] {
            let row = NSStackView(); row.orientation = .horizontal; row.alignment = .top; row.distribution = .fillEqually; row.spacing = 24
            for index in indices { row.addArrangedSubview(columns[index]) }
            body.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        }
        tick(); present()
    }
    @objc func showSettings() {
        guard beginPage("subscription") else { return }; showingSettings = true; let member = read("membership.json")
        heading("Codex subscription record"); paragraph("No sign-up or purchase for this tool. Records are optional.")
        enabled.state = member["enabled"] as? Bool == true ? .on : .off; enabled.target = self; enabled.action = #selector(updateFields); body.addArrangedSubview(enabled)
        plan.removeAllItems(); plan.addItems(withTitles: ["Plus",CqsLocale.t("Pro / unknown tier"),"Pro 100","Pro 200","Pro 500",CqsLocale.t("Business / unknown seat"),"Business Standard","Business Premium","Enterprise","Edu","Free","Go",CqsLocale.t("Other / unknown")])
        let index = planIDs.indices.first { planIDs[$0] == (member["plan"] as? String) && (planTiers[$0] == (member["tier"] as? String ?? "unknown") || planTiers[$0].isEmpty) } ?? 12
        plan.selectItem(at: index); plan.target = self; plan.action = #selector(planChanged)
        for picker in [purchase, next] { picker.datePickerElements = [.yearMonthDay]; picker.datePickerStyle = .textFieldAndStepper; picker.target = self; picker.action = #selector(updateFields) }
        purchase.dateValue = date(member["purchaseDate"] as? String) ?? Date(); next.dateValue = date(member["date"] as? String) ?? Date()
        mode.removeAllItems(); mode.addItems(withTitles: [CqsLocale.t("Monthly estimate"), CqsLocale.t("Set renewal date"), CqsLocale.t("Set expiry date")]); mode.selectItem(at: member["kind"] as? String == "expiry" ? 2 : member["date"] != nil ? 1 : 0); mode.target = self; mode.action = #selector(updateFields)
        mode.addItem(withTitle: CqsLocale.t("Business annual estimate")); if member["annualEstimate"] as? Bool == true { mode.selectItem(at: 3) }
        line(CqsLocale.t("Plan"), plan); line(CqsLocale.t("Purchase date"), purchase); line(CqsLocale.t("Date type"), mode); line(CqsLocale.t("Renewal / expiry"), next); updateFields()
        let commands = NSStackView(); commands.spacing = 8
        saveButton = button("Save", #selector(save), primary: true); commands.addArrangedSubview(saveButton!); body.addArrangedSubview(commands); editingReady = true; present()
    }
    @objc func updateFields() {
        markDirty()
        let free = planIDs[plan.indexOfSelectedItem] == "free"; enabled.isEnabled = !free; if free { enabled.state = .off }
        for control in [purchase as NSControl, mode] { control.isEnabled = enabled.state == .on }
        if mode.indexOfSelectedItem == 3 && planIDs[plan.indexOfSelectedItem] != "business" { mode.selectItem(at: 1) }
        if mode.indexOfSelectedItem == 0 && ["enterprise","edu"].contains(planIDs[plan.indexOfSelectedItem]) { mode.selectItem(at: 1) }
        next.isEnabled = enabled.state == .on && mode.indexOfSelectedItem != 0 && mode.indexOfSelectedItem != 3
        if mode.indexOfSelectedItem == 0 { next.dateValue = Calendar.current.date(byAdding: .month, value: 1, to: purchase.dateValue) ?? purchase.dateValue }
        if mode.indexOfSelectedItem == 3 { next.dateValue = Calendar.current.date(byAdding: .year, value: 1, to: purchase.dateValue) ?? purchase.dateValue }
    }
    @objc func planChanged() { if ["business","enterprise","edu","free"].contains(planIDs[plan.indexOfSelectedItem]) { enabled.state = .off; mode.selectItem(at: 1) }; updateFields() }
    @objc func showDisplay() {
        guard beginPage("display") else { return }; showingSettings = true; displayChecks = []
        let keys = ["short","week","reset","plan","renewal","daily","average","weekly","lifetime","credits","resetCredits"]
        let labels = [CqsLocale.t("5-hour remaining"),CqsLocale.t("Weekly remaining"),CqsLocale.t("Quota reset"),CqsLocale.t("Plan badge"),CqsLocale.t("Renewal date"),CqsLocale.t("Daily tokens"),CqsLocale.t("Monthly daily average"),CqsLocale.t("Weekly tokens"),CqsLocale.t("Lifetime tokens"),CqsLocale.t("Credits"),CqsLocale.t("Available quota resets")]
        let values = read("display.json"), stack = NSStackView(); stack.orientation = .horizontal; stack.alignment = .top; stack.spacing = 20
        let left = NSStackView(), right = NSStackView()
        for column in [left, right] { column.orientation = .vertical; column.alignment = .leading; column.spacing = 8; column.widthAnchor.constraint(equalToConstant: 280).isActive = true; stack.addArrangedSubview(column) }
        func group(_ text: String, _ column: NSStackView) { let label = NSTextField(labelWithString: CqsLocale.t(text)); label.font = .systemFont(ofSize: 12, weight: .regular); label.textColor = .secondaryLabelColor; column.addArrangedSubview(label) }
        group("Quota data", left); group("Token data", right)
        heading("Sidebar display content")
        for (index, pair) in Array(zip(keys,labels)).enumerated() {
            let (key,label) = pair
            if index == 3 { group("Codex subscription record", left) }
            let check = NSButton(checkboxWithTitle: label, target: self, action: #selector(markDirty)); check.font = .systemFont(ofSize: 13, weight: .regular)
            check.heightAnchor.constraint(equalToConstant: 24).isActive = true
            check.state = values[key] as? Bool == false ? .off : .on; displayChecks.append((key,check)); (index < 5 ? left : right).addArrangedSubview(check)
        }
        body.addArrangedSubview(stack)
        paragraph("Official controls have priority. Scroll first; collapse only when space is very limited.")
        paragraph("Changes apply automatically while connected. No reconnect is needed.")
        saveButton = button("Save", #selector(saveDisplay), primary: true); body.addArrangedSubview(saveButton!); editingReady = true; present()
    }
    @objc func saveDisplay() {
        do { try write("display.json", Dictionary(uniqueKeysWithValues: displayChecks.map { ($0.0, $0.1.state == .on) })); saved() }
        catch { alert(error.localizedDescription) }
    }
    func paragraph(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: CqsLocale.t(text)); label.font = .systemFont(ofSize: 13)
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 640).isActive = true; body.addArrangedSubview(label)
    }
    func heading(_ text: String) {
        let label = NSTextField(labelWithString: CqsLocale.t(text)); label.font = .systemFont(ofSize: 22, weight: .regular); body.addArrangedSubview(label)
    }
    @objc func showHelp() {
        guard beginPage("help") else { return }; showingSettings = true; heading("Diagnostics")
        authorizationButtons()
        paragraph("1. Check that official Codex can chat. Enlarge the window if the sidebar is hidden, then reconnect.")
        paragraph("If Codex is already running, reconnect first. When a restart is required, save work and approve it in Usage overview. You can cancel or quit Codex manually instead.")
        paragraph("2. Export diagnostics: version, system, connection state and error codes. No keys, chats, accounts or installation paths.")
        paragraph("3. Review the file, describe how to reproduce the problem, then attach it to a GitHub issue. Hide personal information in screenshots.")
        body.addArrangedSubview(button("Export sanitized diagnostics", #selector(exportDiagnostics)))
        body.addArrangedSubview(button("Submit feedback on GitHub", #selector(openIssues)))
        paragraph("No automatic uploads. You choose what to submit. A GitHub account is required to post an issue."); present()
    }
    @objc func showData() {
        guard beginPage("data") else { return }; showingSettings = true; heading("Data and settings")
        paragraph("Export display choices, language and your manually recorded subscription.")
        body.addArrangedSubview(button("Backup settings", #selector(backupSettings)))
        paragraph("Select a backup and confirm before replacing your current settings.")
        body.addArrangedSubview(button("Restore settings", #selector(restoreSettings)))
        paragraph("Clear local observation times only. Official usage and chats are not deleted.")
        body.addArrangedSubview(button("Clear observation history", #selector(clearHistory))); present()
    }
    @objc func backupSettings() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Codex-Quota-Sidebar-settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try SettingsTransfer.exportData(runtime).write(to: url, options: .atomic) } catch { alert(error.localizedDescription) }
    }
    @objc func restoreSettings() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url); _ = try SettingsTransfer.checked(data)
            let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Select a backup and confirm before replacing your current settings.")
            prompt.addButton(withTitle: CqsLocale.t("Cancel")); prompt.addButton(withTitle: CqsLocale.t("Restore settings"))
            guard prompt.runModal() == .alertSecondButtonReturn else { return }
            try SettingsTransfer.restore(data, at: runtime)
            if let raw = try? Data(contentsOf: runtime.appendingPathComponent("language.json")), let lang = (try? JSONSerialization.jsonObject(with: raw, options: [.fragmentsAllowed])) as? String {
                CqsLocale.language = lang; UserDefaults.standard.set(lang, forKey: "cqs-language")
                languagePicker.selectItem(at: lang == "en" ? 0 : lang == "zh-CN" ? 1 : 2)
            }
            present()
        } catch { alert(error.localizedDescription) }
    }
    @objc func clearHistory() {
        let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Clear local observation history?")
        prompt.addButton(withTitle: CqsLocale.t("Cancel")); prompt.addButton(withTitle: CqsLocale.t("Continue"))
        if prompt.runModal() == .alertSecondButtonReturn { do { try Data("clear".utf8).write(to: runtime.appendingPathComponent("clear-history.request"), options: .atomic) } catch { alert(error.localizedDescription) } }
    }
    @objc func exportDiagnostics() {
        let dialog = NSSavePanel(); dialog.nameFieldStringValue = "Codex-Quota-Sidebar-diagnostics.json"
        guard dialog.runModal() == .OK, let url = dialog.url else { return }
        do {
            let code = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
            let allowedCodes = ["E_CDP_OWNER", "E_CDP_NONLOCAL", "E_CDP_HELPER_SIGNATURE", "E_CDP_QUERY", "E_RESTART_REQUIRED", "E_QUIT_CANCELLED"]
            let report: [String: Any] = ["version": "0.4.8-alpha.1", "platform": "macOS", "stage": stage, "connectionCode": allowedCodes.contains(code) ? code : "", "runtimeReady": runtimeReady, "runtimeIssue": runtimeIssue, "monitorRunning": child?.isRunning == true, "exportedAt": ISO8601DateFormatter().string(from: Date())]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
        } catch { alert(error.localizedDescription) }
    }
    @objc func openIssues() { NSWorkspace.shared.open(URL(string: "https://github.com/kefen/codex-quota-sidebar/issues/new")!) }
    @objc func showAbout() {
        guard beginPage("about") else { return }; showingSettings = true; heading("About project"); paragraph("Codex Quota Sidebar by KEFEN")
        paragraph("Local, read-only quota and Token indicators in the Codex sidebar. Choose the metrics you need; official controls always have priority.")
        paragraph("Unofficial software. Not affiliated with or endorsed by OpenAI.")
        paragraph("Author: KEFEN / License: MIT")
        body.addArrangedSubview(button("Visit GitHub project", #selector(openGitHub)))
        body.addArrangedSubview(button("Show application in Finder", #selector(revealApplication))); present()
    }
    @objc func skip() { enabled.state = .off; save() }
    @objc func save() {
        if enabled.state == .on && mode.indexOfSelectedItem != 0 && mode.indexOfSelectedItem != 3 && dateString(next.dateValue) < dateString(purchase.dateValue) { alert(CqsLocale.t("Renewal/expiry date cannot precede purchase date.")); return }
        var member = read("membership.json"); member["enabled"] = enabled.state == .on
        member["plan"] = planIDs[plan.indexOfSelectedItem]; member["tier"] = planTiers[plan.indexOfSelectedItem]
        if enabled.state == .on {
            member.removeValue(forKey: "date")
            member["purchaseDate"] = dateString(purchase.dateValue); member["kind"] = mode.indexOfSelectedItem == 2 ? "expiry" : "renewal"
            member["monthlyEstimate"] = mode.indexOfSelectedItem == 0; member["annualEstimate"] = mode.indexOfSelectedItem == 3; member["estimated"] = mode.indexOfSelectedItem == 0 || mode.indexOfSelectedItem == 3
            if mode.indexOfSelectedItem != 0 && mode.indexOfSelectedItem != 3 { member["date"] = dateString(next.dateValue) }
        }
        do { try write("membership.json", member); var prefs = read("preferences.json"); prefs["setupComplete"] = true; try write("preferences.json", prefs); saved(); if child == nil { start() } }
        catch { alert(error.localizedDescription) }
    }
    @objc func start() {
        guard child == nil, !stopping, read("preferences.json")["cdpConsent"] as? Bool == true else { return }
        ensureRuntime { [weak self] in self?.launchMonitor() }
    }
    func ensureRuntime(_ next: @escaping () -> Void) {
        if runtimeReady { next(); return }
        guard runtimeProbe == nil else { return }
        let previousStage = stage
        stage = "checking"; runtimeIssue = false
        feedbackUntil = .distantPast; errorText = ""; tick()
        let probe = RuntimeProbe(); runtimeProbe = probe; retry.isEnabled = false
        runtimeAction?.title = CqsLocale.t("Checking runtime"); runtimeAction?.isEnabled = false
        probe.run(root.appendingPathComponent("runtime/node")) { [weak self] outcome in
            guard let self = self else { return }; self.runtimeProbe = nil
            self.runtimeAction?.title = CqsLocale.t("Check runtime and connect"); self.runtimeAction?.isEnabled = true
            if outcome == .ready {
                self.runtimeReady = true; self.runtimeIssue = false
                self.stage = previousStage == "checking" ? "stopped" : previousStage
                var prefs = self.read("preferences.json"); prefs["macGuideVersion"] = "0.4.8-alpha.1"
                try? self.write("preferences.json", prefs); self.tick(); next()
            } else {
                self.stage = "failed"; self.runtimeIssue = true
                let code = outcome == .missing ? "E_RUNTIME_MISSING" : outcome == .timedOut ? "E_RUNTIME_TIMEOUT" : "E_RUNTIME_START"
                self.errorText = CqsLocale.t(outcome == .missing ? "Runtime file missing. Exit and reinstall the complete package." : "Node runtime did not start. If macOS blocked node, review Privacy & Security and the installation guide, then reconnect. This does not establish a Codex signature error.") + "\n" + code
                self.feedbackUntil = .distantPast
                if self.page == "overview" { self.page = "" }
                self.showStatus(); self.tick()
            }
        }
    }
    @objc func showAuthorizationHelp() {
        guard beginPage("authorization") else { return }; showingSettings = true
        heading("Before connecting on Mac")
        paragraph("This experimental app is not notarized. The app and its Node runtime may require separate approval.")
        paragraph("1. Verify the download source and checksum. You may stop and wait for a notarized version.")
        paragraph("2. After a system warning, review the exact item in System Settings > Privacy & Security. If available, choose Open Anyway only if you trust it.")
        paragraph("3. Return here and check the runtime again. Do not disable system protections or grant unrelated permissions.")
        authorizationButtons()
        runtimeAction = button("Check runtime and connect", #selector(start), primary: true)
        body.addArrangedSubview(runtimeAction!); present()
    }
    func authorizationButtons() {
        let actions = NSStackView(); actions.spacing = 12
        actions.addArrangedSubview(button("Open Privacy & Security", #selector(openSecuritySettings)))
        actions.addArrangedSubview(button("Installation and approval guide", #selector(openInstallGuide)))
        body.addArrangedSubview(actions)
    }
    @objc func openSecuritySettings() {
        if !NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!) {
            alert(CqsLocale.t("Open System Settings manually, then choose Privacy & Security."))
        }
    }
    @objc func openInstallGuide() {
        guard let url = Bundle.main.url(forResource: "READ-ME-FIRST", withExtension: "html") else {
            alert(CqsLocale.t("Open READ-ME-FIRST.html in the downloaded disk image.")); return
        }
        NSWorkspace.shared.open(url)
    }
    func launchMonitor() {
        stage = "starting"; errorText = ""; startedAt = Date()
        if page == "authorization" { showStatus() }
        do {
            try? FileManager.default.removeItem(at: runtime.appendingPathComponent("mac-error.txt"))
            let logURL = runtime.appendingPathComponent("mac-ui.log"); try Data().write(to: logURL); log = try FileHandle(forWritingTo: logURL)
            let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node"); process.arguments = [root.appendingPathComponent("mac/launch.mjs").path, "--native-ui"]; process.standardOutput = log; process.standardError = log
            if restartApproved { process.arguments?.append("--restart-approved"); restartApproved = false }
            process.terminationHandler = { [weak self] process in DispatchQueue.main.async {
                guard let self = self else { return }; self.child = nil; try? self.log?.close(); self.log = nil
                if self.stopping { NSApp.terminate(nil); return }
                if self.reconnecting { self.reconnecting = false; self.start(); return }
                self.stage = process.terminationStatus == 0 ? "stopped" : "failed"
                self.errorText = (try? String(contentsOf: self.runtime.appendingPathComponent("mac-error.txt"), encoding: .utf8)) ?? CqsLocale.t("The monitor exited without a connection report. Open Diagnostics and review the installation guide.")
                if self.page == "overview" { self.page = "" }
                self.showStatus()
            }}
            child = process; try process.run(); tick()
        } catch { child = nil; try? log?.close(); log = nil; stage = "failed"; errorText = error.localizedDescription; tick() }
    }
    func tick() {
        let request = runtime.appendingPathComponent("background-open.request")
        if FileManager.default.fileExists(atPath: request.path) { try? FileManager.default.removeItem(at: request); present() }
        retry.isEnabled = runtimeProbe == nil && !stopping && !reconnecting && stage != "starting"
        guard !showingSettings, rows.count == 4 else { return }
        var state: [String: Any] = [:]
        if child?.isRunning == true { state = read("status.json") }
        // A stale status from a previous launch must never turn the startup indicator green.
        if let stamp = state["updatedAt"] as? String {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: stamp), date >= startedAt, abs(date.timeIntervalSinceNow) < 35 { stage = state["stage"] as? String ?? stage } else { state = [:] }
        }
        let mounted = stage.hasPrefix("mounted")
        headline.stringValue = runtimeIssue ? CqsLocale.t("Runtime unavailable") : stage == "checking" ? CqsLocale.t("Checking runtime") : mounted ? CqsLocale.t("Connected") : stage == "failed" ? CqsLocale.t("Connection incomplete") : stage == "stopped" ? CqsLocale.t("Stopped") : CqsLocale.t("Connecting")
        headline.textColor = mounted ? green : .labelColor
        let code = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
        restartButton?.isHidden = stage != "failed" || code != "E_RESTART_REQUIRED"
        let connectionErrors = [
            "E_CDP_OWNER": "The connection port has an unverified owner. Export diagnostics; do not disable security checks.",
            "E_CDP_NONLOCAL": "The connection port is not restricted to this computer. Quit Codex normally and reconnect.",
            "E_CDP_HELPER_SIGNATURE": "The Codex helper could not be verified. Update official Codex or export diagnostics.",
            "E_CDP_QUERY": "macOS could not inspect the connection port. Retry or export diagnostics."
        ]
        let failure = code == "E_RESTART_REQUIRED" ? CqsLocale.t("Codex is open without a connection port. Save your work, then approve a restart to connect.") : code == "E_QUIT_CANCELLED" ? CqsLocale.t("Codex did not quit. No process was forced closed. Save your work and retry, or quit Codex manually and reconnect.") : connectionErrors[code].map { CqsLocale.t($0) + "\n" + code } ?? String(errorText.prefix(240))
        detail.stringValue = stage == "failed" ? failure : mounted ? CqsLocale.t("Sidebar attached.") : CqsLocale.t("Waiting for client and data.")
        rows[0].stringValue = mounted ? CqsLocale.t("Connected") : CqsLocale.t("Not connected")
        for (index, key) in [(1, "quotaAvailable"), (2, "usageAvailable")] { rows[index].stringValue = (state[key] as? Bool).map { $0 ? CqsLocale.t("Synced") : CqsLocale.t("Unavailable") } ?? "--" }
        if let stamp = state["updatedAt"] as? String { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; rows[3].stringValue = f.date(from: stamp).map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .medium) } ?? "--" } else { rows[3].stringValue = "--" }
        retry.isEnabled = runtimeProbe == nil && !stopping && !reconnecting && stage != "starting"
        if feedbackUntil > Date(), stage != "failed", !runtimeIssue { detail.stringValue = feedback }
        updateMetrics(mounted)
        CqsLocale.apply(window.contentView!)
    }
    func updateMetrics(_ connected: Bool) {
        guard metricFields.count == 6 else { return }
        let values = MetricPresentation.values(read("browser-state.json"), connected: connected, now: Date().timeIntervalSince1970 * 1000)
        for (index, value) in values.enumerated() {
            metricFields[index].stringValue = value.value
            metricFields[index].textColor = value.value == "--" ? .secondaryLabelColor : .labelColor
            metricCaptions[index].stringValue = CqsLocale.t(value.caption)
            metricFields[index].toolTip = value.value == "--" ? CqsLocale.t(value.caption) : nil
            if index < quotaTracks.count { quotaTracks[index].fraction = value.fraction }
        }
    }
    @objc func refresh() { do { try Data("refresh".utf8).write(to: runtime.appendingPathComponent("refresh.request"), options: .atomic) } catch { alert(error.localizedDescription) } }
    @objc func reconnect() {
        guard !stopping, !reconnecting else { return }
        notify(CqsLocale.t("Reconnecting; Codex will not be closed automatically."))
        if child == nil { start(); return }
        do { try Data("reconnect".utf8).write(to: runtime.appendingPathComponent("background-stop.request"), options: .atomic); reconnecting = true; retry.isEnabled = false }
        catch { alert(error.localizedDescription) }
    }
    @objc func confirmRestart() {
        guard child == nil, runtimeProbe == nil, !stopping else { return }
        let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Restart Codex to connect?")
        prompt.informativeText = CqsLocale.t("1. Save your work and wait for active tasks to finish.\n2. Codex will receive a normal quit request, then reopen with a local connection port.\n3. Unsaved tasks may be interrupted. Cancel leaves Codex unchanged; no process will be force-closed.")
        prompt.addButton(withTitle: CqsLocale.t("Cancel"))
        let approve = prompt.addButton(withTitle: CqsLocale.t("Save work, restart and connect")); approve.keyEquivalent = ""
        guard prompt.runModal() == .alertSecondButtonReturn else { return }
        restartApproved = true; feedbackUntil = .distantPast; start()
    }
    @objc func openCodex() {
        ensureRuntime { [weak self] in self?.launchCodexFocus() }
    }
    func launchCodexFocus() {
        guard opening == nil else { notify(CqsLocale.t("Opening Codex. Please wait.")); return }
        notify(CqsLocale.t("Opening Codex..."))
        let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node"); process.arguments = [root.appendingPathComponent("mac/launch.mjs").path,"--native-ui","--focus"]
        process.terminationHandler = { [weak self] p in DispatchQueue.main.async { self?.opening = nil; self?.notify(p.terminationStatus == 0 ? CqsLocale.t("Codex activation requested.") : CqsLocale.t("Cannot open Codex. Check signing configuration and install location.")) } }
        do { opening = process; try process.run() } catch { opening = nil; notify(error.localizedDescription) }
    }
    @objc func stop() {
        if let probe = runtimeProbe { runtimeProbe = nil; probe.cancel() }
        guard child?.isRunning == true else { NSApp.terminate(nil); return }
        do { try Data("stop".utf8).write(to: runtime.appendingPathComponent("background-stop.request"), options: .atomic); stopping = true
            stopTimer?.invalidate(); stopTimer = Timer.scheduledTimer(withTimeInterval: 40, repeats: false) { [weak self] _ in
                guard let self = self, self.child?.isRunning == true else { return }; self.stopping = false; self.alert(CqsLocale.t("Startup checks are still running. Try exiting later. Codex will not be force-closed."))
            }
        } catch { alert(error.localizedDescription) }
    }
    @objc func checkUpdates() { runUpdate("check") }
    func runUpdate(_ operation: String) {
        guard updateProcess == nil else { return }
        let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node")
        process.arguments = [root.appendingPathComponent("src/update.mjs").path, operation, root.path, Bundle.main.bundleURL.path, String(ProcessInfo.processInfo.processIdentifier)]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        updateButton.isEnabled = false; updateButton.title = CqsLocale.t(operation == "download" ? "Downloading update..." : "Checking for updates...")
        updateProcess = process
        process.terminationHandler = { [weak self] child in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let self = self else { return }; self.updateProcess = nil; self.updateButton.isEnabled = true; self.updateButton.title = CqsLocale.t("Check for updates")
                guard child.terminationStatus == 0, let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { if operation != "auto" { self.alert(CqsLocale.t("Update check failed. Please try again later.")) }; return }
                if operation == "prepare" { self.stop(); return }
                guard result["available"] as? Bool == true else { if operation != "auto" { self.alert(CqsLocale.t("You are up to date.")) }; return }
                self.updateButton.title = CqsLocale.t("Update available") + " " + (result["version"] as? String ?? "")
                if operation == "auto" { return }
                let ready = result["ready"] as? Bool == true
                let dialog = NSAlert(); dialog.messageText = CqsLocale.t(ready ? "Restart the companion to install the verified update? Codex stays open." : "Download this update in the background?")
                dialog.informativeText = (result["version"] as? String ?? "") + "\n\n" + (result["notes"] as? String ?? "")
                dialog.addButton(withTitle: CqsLocale.t("Cancel")); dialog.addButton(withTitle: CqsLocale.t("Continue"))
                if dialog.runModal() == .alertSecondButtonReturn { self.runUpdate(ready ? "prepare" : "download") }
            }
        }
        do { try process.run() } catch { updateProcess = nil; updateButton.isEnabled = true; updateButton.title = CqsLocale.t("Check for updates"); if operation != "auto" { alert(CqsLocale.t("Update check failed. Please try again later.")) } }
    }
    func alert(_ text: String) {
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke alert: \(text)\n", stderr); exit(1) }
        let a = NSAlert(); a.messageText = "Codex Quota Sidebar"; a.informativeText = text; a.runModal()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { if child?.isRunning == true { stop(); return .terminateCancel }; return .terminateNow }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { present(); return true }
}
@main
struct QuotaMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = QuotaApp()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
