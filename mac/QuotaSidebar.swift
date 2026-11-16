import AppKit

// Native shell only. The shared Node core remains responsible for quota data.
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
    var dirty = false
    var editingReady = false
    var saveButton: NSButton?
    func beginPage(_ next: String) -> Bool {
        if page == next { present(); return false }
        if dirty {
            let dialog = NSAlert(); dialog.messageText = CqsLocale.t("Discard unsaved changes?")
            dialog.addButton(withTitle: CqsLocale.t("Cancel")); dialog.addButton(withTitle: CqsLocale.t("Continue"))
            guard dialog.runModal() == .alertSecondButtonReturn else { return false }
        }
        dirty = false; editingReady = false; saveButton = nil; page = next; clear(); return true
    }
    @objc func markDirty() { if editingReady { dirty = true } }
    func saved() {
        dirty = false
        guard let control = saveButton else { return }
        control.title = CqsLocale.t("Saved successfully"); control.bezelColor = nil; control.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self, weak control] in
            guard let control = control else { return }; control.title = CqsLocale.t("Save"); control.bezelColor = self?.green; control.isEnabled = true
        }
    }
    var metricFields: [NSTextField] = []
    let languagePicker = NSPopUpButton()
    var retry: NSButton!
    var child: Process?
    var log: FileHandle?
    var timer: Timer?
    var stopTimer: Timer?
    var showingSettings = false
    var hiddenAfterMount = false
    var stopping = false
    var reconnecting = false
    var opening: Process?
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
        let header = NSStackView(); header.spacing = 16
        let icon = NSImageView(image: NSImage(contentsOf: root.appendingPathComponent("assets/cqs-128.png")) ?? NSImage())
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true; icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let words = NSStackView(); words.orientation = .vertical; words.alignment = .leading; words.spacing = 4
        let title = NSTextField(labelWithString: "Codex Quota Sidebar"); title.font = .systemFont(ofSize: 21, weight: .regular)
        let version = NSTextField(labelWithString: "by KEFEN"); version.textColor = .secondaryLabelColor
        words.addArrangedSubview(title); words.addArrangedSubview(version); header.addArrangedSubview(icon); header.addArrangedSubview(words); container.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        let headerGap = NSView(); header.addArrangedSubview(headerGap); headerGap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        languagePicker.identifier = NSUserInterfaceItemIdentifier("language")
        languagePicker.addItems(withTitles: ["English", "简体中文", "繁體中文"])
        languagePicker.selectItem(at: CqsLocale.language == "en" ? 0 : CqsLocale.language == "zh-CN" ? 1 : 2)
        languagePicker.target = self; languagePicker.action = #selector(changeLanguage); header.addArrangedSubview(languagePicker)
        let divider = NSBox(); divider.boxType = .separator; container.addArrangedSubview(divider); divider.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        let split = NSStackView(); split.orientation = .horizontal; split.alignment = .top; split.spacing = 30
        let navigation = NSStackView(); navigation.orientation = .vertical; navigation.alignment = .leading; navigation.spacing = 14
        navigation.wantsLayer = true; navigation.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
        navigation.edgeInsets = NSEdgeInsets(top: 18, left: 12, bottom: 18, right: 12)
        for (label, action) in [("Usage overview", #selector(showStatus)), ("Sidebar content", #selector(showDisplay)), ("Codex subscription record", #selector(showSettings)), ("Data and settings", #selector(showData)), ("Diagnostics", #selector(showHelp)), ("About project", #selector(showAbout))] { navigation.addArrangedSubview(button(label, action)) }
        navigation.widthAnchor.constraint(equalToConstant: 205).isActive = true
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 14; split.addArrangedSubview(navigation); split.addArrangedSubview(body); container.addArrangedSubview(split)
        body.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -283).isActive = true
        let spacer = NSView(); container.addArrangedSubview(spacer); spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        let footer = NSStackView(); footer.spacing = 8
        let build = NSTextField(labelWithString: "macOS 0.4.1-alpha.1"); build.textColor = .secondaryLabelColor
        footer.addArrangedSubview(build)
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
        statusItem.menu = menu; showStatus()
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
        start()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.tick() }
    }
    func button(_ title: String, _ action: Selector, primary: Bool = false) -> NSButton {
        let result = NSButton(title: CqsLocale.t(title), target: self, action: action); result.bezelStyle = .rounded; result.font = .systemFont(ofSize: 13, weight: .regular)
        if primary { result.bezelColor = green }
        result.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true; return result
    }
    func smokeTest() {
        do {
            let output = URL(fileURLWithPath: CommandLine.arguments.last!); try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for language in ["en", "zh-CN", "zh-TW"] {
                CqsLocale.language = language; languagePicker.selectItem(at: language == "en" ? 0 : language == "zh-CN" ? 1 : 2)
                for action in [showStatus, showDisplay, showSettings, showData, showHelp, showAbout] {
                    action(); CqsLocale.apply(window.contentView!); window.contentView!.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                    if page == "subscription" { plan.selectItem(at: 2); enabled.state = .on; updateFields(); save(); precondition(!dirty && page == "subscription" && saveButton?.isEnabled == false) }
                    if page == "display" { saveDisplay(); precondition(!dirty && page == "display") }
                    let view = window.contentView!
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(page + "-" + language + ".png"))
                }
            }
            let backup = try SettingsTransfer.exportData(runtime); try SettingsTransfer.restore(backup, at: runtime)
            do { _ = try SettingsTransfer.checked(Data("{\"auth.json\":{\"token\":\"do-not-import\"}}".utf8)); fatalError("Unknown settings accepted") } catch {}
            print("PASS: native Mac pages, three languages, save persistence and settings boundary; synthetic fixture only")
            NSApp.terminate(nil)
        } catch { fputs("UI smoke failed: \(error)\n", stderr); exit(1) }
    }
    func clear() { for view in body.arrangedSubviews { body.removeArrangedSubview(view); view.removeFromSuperview() } }
    func present() { CqsLocale.apply(window.contentView!); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func openGitHub() { NSWorkspace.shared.open(CqsLocale.repository) }
    @objc func changeLanguage() {
        CqsLocale.language = ["en","zh-CN","zh-TW"][languagePicker.indexOfSelectedItem]
        UserDefaults.standard.set(CqsLocale.language, forKey: "cqs-language")
        try? Data(("\"" + CqsLocale.language + "\"").utf8).write(to: runtime.appendingPathComponent("language.json"), options: .atomic)
        CqsLocale.apply(window.contentView!)
        for item in statusItem.menu?.items ?? [] { item.title = CqsLocale.t(item.title) }
    }
    func line(_ label: String, _ value: NSView) {
        let row = NSStackView(); row.spacing = 20; let key = NSTextField(labelWithString: CqsLocale.t(label)); key.textColor = .secondaryLabelColor
        key.widthAnchor.constraint(equalToConstant: 130).isActive = true; row.addArrangedSubview(key); row.addArrangedSubview(value); body.addArrangedSubview(row)
    }
    @objc func showStatus() {
        guard beginPage("overview") else { return }; showingSettings = false; rows = []
        headline.font = .systemFont(ofSize: 26, weight: .regular); body.addArrangedSubview(headline); body.addArrangedSubview(detail)
        detail.widthAnchor.constraint(lessThanOrEqualToConstant: 600).isActive = true
        for title in [CqsLocale.t("Client"), CqsLocale.t("Quota data"), CqsLocale.t("Token data"), CqsLocale.t("Last sync")] { let field = NSTextField(labelWithString: "--"); rows.append(field); line(title, field) }
        metricFields = []
        let metrics = NSStackView(); metrics.orientation = .horizontal; metrics.spacing = 12
        for label in ["5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens"] {
            let column = NSStackView(); column.orientation = .vertical; column.alignment = .leading; column.spacing = 8
            column.widthAnchor.constraint(equalToConstant: 110).isActive = true
            let name = NSTextField(wrappingLabelWithString: CqsLocale.t(label)); name.font = .systemFont(ofSize: 11)
            let value = NSTextField(labelWithString: "--"); value.font = .systemFont(ofSize: 22, weight: .regular)
            column.addArrangedSubview(name); column.addArrangedSubview(value); metrics.addArrangedSubview(column); metricFields.append(value)
        }
        body.addArrangedSubview(metrics)
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
        let keys = ["plan","short","week","reset","renewal","daily","average","weekly","lifetime"]
        let labels = [CqsLocale.t("Plan badge"),CqsLocale.t("5-hour remaining"),CqsLocale.t("Weekly remaining"),CqsLocale.t("Quota reset"),CqsLocale.t("Renewal date"),CqsLocale.t("Daily tokens"),CqsLocale.t("Daily average"),CqsLocale.t("Weekly tokens"),CqsLocale.t("Lifetime tokens")]
        let values = read("display.json"), stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        heading("Sidebar display content")
        for (key,label) in zip(keys,labels) { let check = NSButton(checkboxWithTitle: label, target: self, action: #selector(markDirty)); check.state = values[key] as? Bool == false ? .off : .on; displayChecks.append((key,check)); stack.addArrangedSubview(check) }
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
        let label = NSTextField(labelWithString: CqsLocale.t(text)); label.font = .systemFont(ofSize: 24, weight: .regular); body.addArrangedSubview(label)
    }
    @objc func showHelp() {
        guard beginPage("help") else { return }; showingSettings = true; heading("Diagnostics")
        paragraph("1. Check that official Codex can chat. Enlarge the window if the sidebar is hidden, then reconnect.")
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
            let report: [String: Any] = ["version": "0.4.1-alpha.1", "platform": "macOS", "stage": stage, "monitorRunning": child?.isRunning == true, "exportedAt": ISO8601DateFormatter().string(from: Date())]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
        } catch { alert(error.localizedDescription) }
    }
    @objc func openIssues() { NSWorkspace.shared.open(URL(string: "https://github.com/kefen/codex-quota-sidebar/issues/new")!) }
    @objc func showAbout() {
        guard beginPage("about") else { return }; showingSettings = true; heading("About project"); paragraph("Codex Quota Sidebar by KEFEN")
        paragraph("Local, read-only quota and Token indicators in the Codex sidebar. Choose the metrics you need; official controls always have priority.")
        paragraph("Unofficial software. Not affiliated with or endorsed by OpenAI.")
        paragraph("Author: KEFEN / License: MIT")
        body.addArrangedSubview(button("Visit GitHub project", #selector(openGitHub))); present()
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
        hiddenAfterMount = false; stage = "starting"; errorText = ""; startedAt = Date()
        do {
            try? FileManager.default.removeItem(at: runtime.appendingPathComponent("mac-error.txt"))
            let logURL = runtime.appendingPathComponent("mac-ui.log"); try Data().write(to: logURL); log = try FileHandle(forWritingTo: logURL)
            let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node"); process.arguments = [root.appendingPathComponent("mac/launch.mjs").path, "--native-ui"]; process.standardOutput = log; process.standardError = log
            process.terminationHandler = { [weak self] process in DispatchQueue.main.async {
                guard let self = self else { return }; self.child = nil; try? self.log?.close(); self.log = nil
                if self.stopping { NSApp.terminate(nil); return }
                if self.reconnecting { self.reconnecting = false; self.start(); return }
                self.stage = process.terminationStatus == 0 ? "stopped" : "failed"
                self.errorText = (try? String(contentsOf: self.runtime.appendingPathComponent("mac-error.txt"), encoding: .utf8)) ?? ""
                self.showStatus()
            }}
            child = process; try process.run(); tick()
        } catch { child = nil; try? log?.close(); log = nil; stage = "failed"; errorText = error.localizedDescription; tick() }
    }
    func tick() {
        let request = runtime.appendingPathComponent("background-open.request")
        if FileManager.default.fileExists(atPath: request.path) { try? FileManager.default.removeItem(at: request); present() }
        retry.isEnabled = !stopping && !reconnecting && stage != "starting"
        guard !showingSettings, rows.count == 4 else { return }
        var state: [String: Any] = [:]
        if child?.isRunning == true { state = read("status.json") }
        // A stale status from a previous launch must never turn the startup indicator green.
        if let stamp = state["updatedAt"] as? String {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: stamp), date >= startedAt, abs(date.timeIntervalSinceNow) < 35 { stage = state["stage"] as? String ?? stage } else { state = [:] }
        }
        let mounted = stage.hasPrefix("mounted")
        headline.stringValue = mounted ? CqsLocale.t("Connected") : stage == "failed" ? CqsLocale.t("Connection incomplete") : stage == "stopped" ? CqsLocale.t("Stopped") : CqsLocale.t("Connecting")
        headline.textColor = mounted ? green : .labelColor
        detail.stringValue = stage == "failed" ? String(errorText.prefix(240)) : mounted ? CqsLocale.t("Sidebar attached.") : CqsLocale.t("Waiting for client and data.")
        rows[0].stringValue = mounted ? CqsLocale.t("Connected") : CqsLocale.t("Not connected")
        for (index, key) in [(1, "quotaAvailable"), (2, "usageAvailable")] { rows[index].stringValue = (state[key] as? Bool).map { $0 ? CqsLocale.t("Synced") : CqsLocale.t("Unavailable") } ?? "--" }
        if let stamp = state["updatedAt"] as? String { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; rows[3].stringValue = f.date(from: stamp).map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .medium) } ?? "--" } else { rows[3].stringValue = "--" }
        retry.isEnabled = !stopping && !reconnecting && stage != "starting"
        if feedbackUntil > Date() { detail.stringValue = feedback }
        updateMetrics(mounted)
        CqsLocale.apply(window.contentView!)
        if mounted && !hiddenAfterMount { hiddenAfterMount = true; DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in if let self = self, self.stage.hasPrefix("mounted"), !self.showingSettings { self.window.orderOut(nil) } } }
    }
    func updateMetrics(_ connected: Bool) {
        for field in metricFields { field.stringValue = "--" }
        guard connected, metricFields.count == 5 else { return }
        let snapshot = read("browser-state.json"), now = Date().timeIntervalSince1970 * 1000
        func fresh(_ key: String, _ limit: Double) -> Bool { guard let stamp = snapshot[key] as? Double else { return false }; return now >= stamp && now - stamp < limit }
        guard fresh("generatedAt",90000) else { return }
        if fresh("quotaAt",180000) {
            let windows = snapshot["windows"] as? [[String:Any]] ?? []
            for (index, minutes) in [(0,300),(1,10080)] {
                let matches = windows.filter { ($0["minutes"] as? Int) == minutes }
                if matches.count == 1, let value = matches[0]["remaining"] as? Double, value.isFinite, value >= 0, value <= 100 { metricFields[index].stringValue = String(format: "%.0f%%",value) }
            }
        }
        if fresh("usageAt",5400000) {
            let daily = snapshot["daily"] as? [String:Any] ?? [:]
            for (index, value) in [(2,daily["value"]),(3,snapshot["week"]),(4,snapshot["lifetime"])] {
                if let count = value as? Double, count.isFinite, count >= 0, count.rounded() == count, count <= 9007199254740991 { metricFields[index].stringValue = count >= 1000000 ? String(format: "%.1fM",count/1000000) : String(format: "%.0f",count) }
            }
            if let date = daily["date"] as? String, date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                metricFields[2].stringValue += "\n" + date
                metricFields[2].toolTip = CqsLocale.t("Data date") + ": " + date
            } else { metricFields[2].stringValue = "--" }
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
    @objc func openCodex() {
        guard opening == nil else { notify(CqsLocale.t("Opening Codex. Please wait.")); return }
        notify(CqsLocale.t("Opening Codex..."))
        let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node"); process.arguments = [root.appendingPathComponent("mac/launch.mjs").path,"--native-ui","--focus"]
        process.terminationHandler = { [weak self] p in DispatchQueue.main.async { self?.opening = nil; self?.notify(p.terminationStatus == 0 ? CqsLocale.t("Codex activation requested.") : CqsLocale.t("Cannot open Codex. Check signing configuration and install location.")) } }
        do { opening = process; try process.run() } catch { opening = nil; notify(error.localizedDescription) }
    }
    @objc func stop() {
        guard child?.isRunning == true else { NSApp.terminate(nil); return }
        do { try Data("stop".utf8).write(to: runtime.appendingPathComponent("background-stop.request"), options: .atomic); stopping = true
            stopTimer?.invalidate(); stopTimer = Timer.scheduledTimer(withTimeInterval: 40, repeats: false) { [weak self] _ in
                guard let self = self, self.child?.isRunning == true else { return }; self.stopping = false; self.alert(CqsLocale.t("Startup checks are still running. Try exiting later. Codex will not be force-closed."))
            }
        } catch { alert(error.localizedDescription) }
    }
    func alert(_ text: String) { let a = NSAlert(); a.messageText = "Codex Quota Sidebar"; a.informativeText = text; a.runModal() }
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
