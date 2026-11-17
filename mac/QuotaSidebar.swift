import AppKit
import Darwin

final class PageDocument: NSView {
    override var isFlipped: Bool { true }
}

// NSDatePicker has no nil value. Keep presence explicit instead of inventing a date.
final class OptionalDatePicker: NSStackView {
    let picker = NSDatePicker()
    let presence = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    var onChange: (() -> Void)?
    var isEnabled = true { didSet { presence.isEnabled = isEnabled; picker.isEnabled = isEnabled && presence.state == .on } }
    var stringValue: String {
        get {
            guard presence.state == .on else { return "" }
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
            return f.string(from: picker.dateValue)
        }
        set {
            let value = MetricPresentation.recordDate(newValue)
            presence.state = value == nil ? .off : .on
            if let value = value { picker.dateValue = value }
            picker.isEnabled = isEnabled && value != nil
        }
    }
    init() {
        super.init(frame: .zero)
        orientation = .horizontal; alignment = .centerY; spacing = 8
        picker.datePickerStyle = .textFieldAndStepper; picker.datePickerElements = .yearMonthDay
        picker.presentsCalendarOverlay = true; picker.font = .systemFont(ofSize: 14)
        picker.calendar = Calendar(identifier: .gregorian)
        picker.target = self; picker.action = #selector(changed)
        presence.target = self; presence.action = #selector(changed)
        addArrangedSubview(presence); addArrangedSubview(picker)
        heightAnchor.constraint(equalToConstant: 36).isActive = true
        stringValue = ""
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func localize(_ title: String) {
        picker.locale = Locale(identifier: CqsLocale.language)
        picker.setAccessibilityLabel(CqsLocale.t(title))
        presence.setAccessibilityLabel(CqsLocale.t("Set date") + ": " + CqsLocale.t(title))
        presence.toolTip = CqsLocale.t("Set date")
    }
    @objc func changed() { picker.isEnabled = isEnabled && presence.state == .on; onChange?() }
}

private func drawSymbol(_ image: NSImage, in rect: NSRect, color: NSColor) {
    let tinted = NSImage(size: rect.size, flipped: false) { bounds in
        image.draw(in: bounds)
        color.setFill(); bounds.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: rect)
}

final class FlatPopUpButton: NSPopUpButton {
    var leadingSymbol: String? { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    override var intrinsicContentSize: NSSize {
        let text = selectedItem?.title ?? ""
        let width = (text as NSString).size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 13)]).width
        return NSSize(width: max(80, ceil(width) + (leadingSymbol == nil ? 36 : 52)), height: 36)
    }
    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        let border = NSBezierPath(roundedRect: frame, xRadius: 4, yRadius: 4)
        NSColor.white.setFill(); border.fill()
        NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.85, alpha: 1).setStroke(); border.stroke()
        let color = isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        var left: CGFloat = 12
        if let symbol = leadingSymbol, let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            drawSymbol(image, in: NSRect(x: 10, y: (bounds.height - 16) / 2, width: 16, height: 16), color: .secondaryLabelColor)
            left = 30
        }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 13), .foregroundColor: color, .paragraphStyle: paragraph]
        let text = selectedItem?.title ?? ""
        let height = (text as NSString).size(withAttributes: attributes).height
        (text as NSString).draw(in: NSRect(x: left, y: (bounds.height - height) / 2, width: max(0, bounds.width - left - 22), height: height), withAttributes: attributes)
        if let arrow = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil) {
            drawSymbol(arrow, in: NSRect(x: bounds.width - 18, y: (bounds.height - 10) / 2, width: 10, height: 10), color: color)
        }
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke(); border.lineWidth = 2; border.stroke()
        }
    }
}

final class FlatButton: NSButton {
    override var intrinsicContentSize: NSSize {
        let size = (title as NSString).size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 13)])
        return NSSize(width: size.width + (image == nil ? 28 : 50), height: 36)
    }
    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted { NSColor.labelColor.withAlphaComponent(0.06).setFill(); NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill() }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 13), .foregroundColor: isEnabled ? (contentTintColor ?? .labelColor) : NSColor.disabledControlTextColor, .paragraphStyle: paragraph]
        let height = (title as NSString).size(withAttributes: attributes).height
        let inset: CGFloat = image == nil ? 12 : 34
        if let image = image { drawSymbol(image, in: NSRect(x: 12, y: (bounds.height - 16) / 2, width: 16, height: 16), color: isEnabled ? (contentTintColor ?? .labelColor) : .disabledControlTextColor) }
        (title as NSString).draw(in: NSRect(x: inset, y: (bounds.height - height) / 2, width: bounds.width - inset - 12, height: height), withAttributes: attributes)
    }
}

// Native shell only. The shared Node core remains responsible for quota data.
final class QuotaTrack: NSView {
    var fraction: Double? { didSet { needsDisplay = true } }
    var tone = NSColor(calibratedRed: 0.157, green: 0.384, blue: 0.827, alpha: 1)
    var plot = false
    override func draw(_ dirtyRect: NSRect) {
        let y = plot ? (bounds.height - 2) / 2 : 0
        NSColor(calibratedRed: 0.91, green: 0.93, blue: 0.95, alpha: 1).setFill()
        NSRect(x: 0, y: y, width: bounds.width, height: plot ? 2 : bounds.height).fill()
        if let value = fraction {
            tone.setFill(); let x = bounds.width * min(1, max(0, value))
            NSRect(x: 0, y: y, width: x, height: plot ? 2 : bounds.height).fill()
            if plot { NSBezierPath(ovalIn: NSRect(x: min(bounds.width - 12, max(0, x - 6)), y: (bounds.height - 12) / 2, width: 12, height: 12)).fill() }
        }
        if !plot { NSColor.white.setFill(); for i in 1..<10 { NSRect(x: bounds.width * CGFloat(i) / 10 - 2, y: 0, width: 4, height: bounds.height).fill() } }
    }
}

final class QuotaApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    let root = CommandLine.arguments.contains("--ui-smoke") ? FileManager.default.temporaryDirectory.appendingPathComponent("cqs-ui-test-" + UUID().uuidString) : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexSidebarMeter")
    var runtime: URL { root.appendingPathComponent(".runtime") }
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var body = NSStackView()
    let pageScroll = NSScrollView()
    let pageDocument = PageDocument()
    var responsiveLayouts: [(CGFloat) -> Void] = []
    var connectionTimer: Timer?
    var connectionAnimationStart: Date?
    var connectionFrame = 0
    var planFailure = ""
    var updateNotice: NSButton!
    var updateAvailable = false
    var availableVersion = ""
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
    func lifecycle(_ event: String) {
        guard CommandLine.arguments.contains("--ui-smoke") || CommandLine.arguments.contains("--update-transaction") else { return }
        fputs("Native lifecycle: \(event)\n", stderr); fflush(stderr)
    }
    func beginPage(_ next: String) -> Bool {
        if page == next { present(); return false }
        if dirty {
            if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: unexpected unsaved changes before \(next)\n", stderr); exit(1) }
            guard resolvePendingEdits() else { return false }
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
    var overviewValues: [String: NSTextField] = [:]
    var overviewCaptions: [String: NSTextField] = [:]
    var overviewTracks: [String: QuotaTrack] = [:]
    var dailyLabel: NSTextField?
    var dailyNote: NSTextField?
    var overviewSignature = ""
    var planProcess: Process?
    var planTimeout: Timer?
    weak var detectPlanButton: NSButton?
    var autoPlanAttempted = false
    var planSource = "manual"
    var familyEdited = false
    let planSourceField = NSTextField(labelWithString: "")
    let tier = FlatPopUpButton()
    let selectionCount = NSTextField(labelWithString: "")
    let languagePicker = FlatPopUpButton()
    var retry: NSButton!
    var updateButton: NSButton!
    var updateProcess: Process?
    var updatePreparationSheet: NSPanel?
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
    let plan = FlatPopUpButton()
    let purchase = OptionalDatePicker()
    let mode = FlatPopUpButton()
    let next = OptionalDatePicker()
    let green = NSColor(calibratedRed: 0.157, green: 0.392, blue: 0.843, alpha: 1)
    func read(_ name: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: runtime.appendingPathComponent(name)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }
    func readForSave(_ name: String) throws -> [String: Any] {
        let url = runtime.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw NSError(domain: "CQS", code: 2, userInfo: [NSLocalizedDescriptionKey: CqsLocale.t("E_CONFIG_INVALID")])
        }
        return value
    }
    func write(_ name: String, _ value: [String: Any]) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: runtime.appendingPathComponent(name), options: .atomic)
    }
    func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    func date(_ text: String?) -> Date? {
        MetricPresentation.recordDate(text)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: launch\n", stderr) }
        guard checkInstallLocation() else { NSApp.terminate(nil); return }
        do { try Bootstrap.install(at: root); try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true) }
        catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        if let data = try? Data(contentsOf: runtime.appendingPathComponent("language.json")), let saved = (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? String, ["en", "zh-CN", "zh-TW"].contains(saved) { CqsLocale.language = saved }
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1184, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 820, height: 520)
        window.collectionBehavior = [.fullScreenPrimary]
        window.title = "Codex Quota Sidebar"; window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.contentView!.wantsLayer = true
        window.contentView!.layer?.backgroundColor = NSColor.white.cgColor
        let container = NSStackView(); container.orientation = .vertical; container.alignment = .leading; container.spacing = 0
        container.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        container.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(container)
        NSLayoutConstraint.activate([container.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor), container.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor), container.topAnchor.constraint(equalTo: window.contentView!.topAnchor), container.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)])
        let header = NSStackView(); header.spacing = 16; header.distribution = .fill; header.alignment = .centerY
        header.heightAnchor.constraint(equalToConstant: 80).isActive = true
        header.edgeInsets = NSEdgeInsets(top: 20, left: 28, bottom: 20, right: 26)
        let icon = NSImageView(image: NSImage(contentsOf: root.appendingPathComponent("assets/cqs-128.png")) ?? NSImage())
        icon.widthAnchor.constraint(equalToConstant: 38).isActive = true; icon.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let words = NSStackView(); words.orientation = .vertical; words.alignment = .leading; words.spacing = 4
        let title = NSTextField(labelWithString: "Codex Quota Sidebar"); title.font = .systemFont(ofSize: 17, weight: .regular)
        title.identifier = NSUserInterfaceItemIdentifier("brand-title")
        let version = NSTextField(labelWithString: "by KEFEN"); version.textColor = .secondaryLabelColor
        words.addArrangedSubview(title); words.addArrangedSubview(version); header.addArrangedSubview(icon); header.addArrangedSubview(words); container.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        let headerGap = NSView(); header.addArrangedSubview(headerGap); headerGap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerGap.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        header.setVisibilityPriority(.mustHold, for: icon); header.setVisibilityPriority(.mustHold, for: words)
        updateButton = button("Check for updates", #selector(checkUpdates))
        updateNotice = NSButton(image: NSImage(systemSymbolName: "bell.badge", accessibilityDescription: CqsLocale.t("Update available")) ?? NSImage(), target: self, action: #selector(checkUpdates))
        updateNotice.bezelStyle = .texturedRounded; updateNotice.imagePosition = .imageOnly
        updateNotice.setAccessibilityLabel(CqsLocale.t("Update available")); updateNotice.toolTip = CqsLocale.t("Update available")
        updateNotice.isHidden = true; header.addArrangedSubview(updateNotice)
        updateNotice.widthAnchor.constraint(equalToConstant: 36).isActive = true
        updateNotice.heightAnchor.constraint(equalToConstant: 36).isActive = true
        languagePicker.identifier = NSUserInterfaceItemIdentifier("language")
        languagePicker.font = .systemFont(ofSize: 13, weight: .regular); languagePicker.isBordered = false; languagePicker.leadingSymbol = "character.bubble"
        languagePicker.heightAnchor.constraint(equalToConstant: 36).isActive = true
        languagePicker.setContentHuggingPriority(.required, for: .horizontal)
        languagePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        languagePicker.addItems(withTitles: ["English", "简体中文", "繁體中文"])
        languagePicker.selectItem(at: CqsLocale.language == "en" ? 0 : CqsLocale.language == "zh-CN" ? 1 : 2)
        languagePicker.target = self; languagePicker.action = #selector(changeLanguage); header.addArrangedSubview(languagePicker)
        let divider = NSBox(); divider.boxType = .separator; divider.heightAnchor.constraint(equalToConstant: 1).isActive = true; container.addArrangedSubview(divider); divider.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        let split = NSView(); split.translatesAutoresizingMaskIntoConstraints = false
        let navigation = NSStackView(); navigation.orientation = .vertical; navigation.alignment = .leading; navigation.spacing = 4
        navigation.wantsLayer = true; navigation.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
        navigation.edgeInsets = NSEdgeInsets(top: 18, left: 12, bottom: 18, right: 12)
        for (key, label, action) in [("overview", "Usage overview", #selector(showStatus)), ("display", "Display choices", #selector(showDisplay)), ("subscription", "Plan and dates", #selector(showSettings)), ("data", "Data and settings", #selector(showData)), ("help", "Diagnostics", #selector(showHelp)), ("about", "About project", #selector(showAbout))] {
            if key == "about" { let space = NSView(); navigation.addArrangedSubview(space); space.setContentHuggingPriority(.defaultLow, for: .vertical) }
            let control = button(label, action); control.alignment = .left
            control.font = .systemFont(ofSize: 14, weight: .medium)
            for constraint in control.constraints where constraint.firstAttribute == .width { constraint.isActive = false }
            control.layer?.borderWidth = 0; control.layer?.backgroundColor = NSColor.clear.cgColor
            control.widthAnchor.constraint(equalToConstant: 184).isActive = true
            setIcon(control, ["overview": "square.grid.2x2", "display": "sidebar.left", "subscription": "checkmark.seal", "data": "slider.horizontal.3", "help": "lifepreserver", "about": "info.circle"][key]!)
            navigationButtons.append((key, control)); navigation.addArrangedSubview(control)
        }
        navigation.widthAnchor.constraint(equalToConstant: 208).isActive = true
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 14; body.distribution = .fill
        body.setContentHuggingPriority(.required, for: .vertical)
        navigation.translatesAutoresizingMaskIntoConstraints = false; body.translatesAutoresizingMaskIntoConstraints = false
        pageScroll.translatesAutoresizingMaskIntoConstraints = false
        pageScroll.drawsBackground = false; pageScroll.hasVerticalScroller = true; pageScroll.autohidesScrollers = true
        pageScroll.hasHorizontalScroller = false; pageScroll.horizontalScrollElasticity = .none; pageScroll.verticalScrollElasticity = .none
        pageScroll.scrollerStyle = .overlay
        pageDocument.translatesAutoresizingMaskIntoConstraints = false
        pageScroll.documentView = pageDocument; pageDocument.addSubview(body)
        split.addSubview(navigation); split.addSubview(pageScroll); container.addArrangedSubview(split)
        let naturalHeight = pageDocument.heightAnchor.constraint(equalTo: body.heightAnchor)
        naturalHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            split.widthAnchor.constraint(equalTo: container.widthAnchor),
            navigation.leadingAnchor.constraint(equalTo: split.leadingAnchor),
            navigation.topAnchor.constraint(equalTo: split.topAnchor),
            navigation.bottomAnchor.constraint(equalTo: split.bottomAnchor),
            pageScroll.leadingAnchor.constraint(equalTo: navigation.trailingAnchor, constant: 24),
            pageScroll.trailingAnchor.constraint(equalTo: split.trailingAnchor, constant: -24),
            pageScroll.topAnchor.constraint(equalTo: split.topAnchor),
            pageScroll.bottomAnchor.constraint(equalTo: split.bottomAnchor),
            pageDocument.widthAnchor.constraint(equalTo: pageScroll.contentView.widthAnchor),
            pageDocument.heightAnchor.constraint(greaterThanOrEqualTo: pageScroll.contentView.heightAnchor), naturalHeight,
            body.leadingAnchor.constraint(equalTo: pageDocument.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: pageDocument.trailingAnchor),
            body.topAnchor.constraint(equalTo: pageDocument.topAnchor),
            body.bottomAnchor.constraint(lessThanOrEqualTo: pageDocument.bottomAnchor)
        ])
        body.edgeInsets = NSEdgeInsets(top: 26, left: 0, bottom: 12, right: 0)
        let footer = NSStackView(); footer.spacing = 8
        footer.edgeInsets = NSEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        footer.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let build = NSTextField(labelWithString: "macOS " + (Bootstrap.releaseVersion ?? "--")); build.textColor = .secondaryLabelColor; build.font = .systemFont(ofSize: 11)
        footer.addArrangedSubview(build)
        let gap = NSView(); footer.addArrangedSubview(gap); gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        retry = button("Reconnect", #selector(reconnect))
        let quit = button("Exit software", #selector(stop)); quit.layer?.borderWidth = 0; setIcon(quit, "power")
        setIcon(retry, "arrow.clockwise")
        let open = button("Open Codex", #selector(openCodex), primary: true); setIcon(open, "arrow.up.right")
        open.identifier = NSUserInterfaceItemIdentifier("open-codex")
        footer.addArrangedSubview(quit); footer.addArrangedSubview(retry); footer.addArrangedSubview(open)
        let footerLine = NSBox(); footerLine.boxType = .separator; footerLine.heightAnchor.constraint(equalToConstant: 1).isActive = true; container.addArrangedSubview(footerLine); footerLine.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        container.addArrangedSubview(footer); footer.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        footer.identifier = NSUserInterfaceItemIdentifier("window-footer")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(contentsOf: root.appendingPathComponent("assets/tray-template.png")) { image.isTemplate = true; image.size = NSSize(width: 18, height: 18); statusItem.button?.image = image }
        statusItem.button?.toolTip = "Codex Quota Sidebar"
        let menu = NSMenu()
        for (text, action) in [(CqsLocale.t("View status"), #selector(showStatus)), (CqsLocale.t("Settings"), #selector(showSettings)), (CqsLocale.t("Sidebar items"), #selector(showDisplay)), (CqsLocale.t("Refresh data"), #selector(refresh)), (CqsLocale.t("Exit software"), #selector(stop))] {
            let item = NSMenuItem(title: text, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: initial overview\n", stderr) }
        lifecycle("initial overview begin")
        showStatus()
        lifecycle("initial overview returned; layout begin")
        window.contentView!.layoutSubtreeIfNeeded()
        lifecycle("initial layout returned; display begin")
        window.displayIfNeeded()
        lifecycle("initial display returned; acknowledgement begin")
        do { try Bootstrap.acknowledgeUpdate(at: root, arguments: CommandLine.arguments, version: Bootstrap.releaseVersion, bundleURL: Bundle.main.bundleURL) }
        catch { notify(CqsLocale.t("Update verification failed. Open Diagnostics.")) }
        lifecycle("acknowledgement returned")
        if !CommandLine.arguments.contains("--ui-smoke") { DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.runUpdate("auto") } }
        if !CommandLine.arguments.contains("--ui-smoke") { Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { [weak self] _ in self?.runUpdate("auto") } }
        if CommandLine.arguments.contains("--ui-smoke") {
            lifecycle("scheduling smoke callback")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.lifecycle("smoke callback entered"); self.smokeTest() }
            lifecycle("launch delegate returning to run loop"); return
        }
        if read("preferences.json")["cdpConsent"] as? Bool != true {
            let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Allow local debugging"); prompt.informativeText = CqsLocale.t("Debugging grants more than quota access. Other local programs may access the port. Stopping the meter does not close it: fully quit Codex and reopen from its official entry. This is unofficial software. Verify that the CLI and desktop accounts match.")
            prompt.addButton(withTitle: CqsLocale.t("Cancel")); let agree = prompt.addButton(withTitle: CqsLocale.t("Agree and continue")); agree.keyEquivalent = ""
            guard prompt.runModal() == .alertSecondButtonReturn else { NSApp.terminate(nil); return }
            do { var prefs = read("preferences.json"); prefs["cdpConsent"] = true; try write("preferences.json", prefs) }
            catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.tick() }
        if (read("preferences.json")["macGuideVersion"] as? String ?? "").isEmpty { stage = "stopped"; showAuthorizationHelp() }
        else { start() }
    }
    func setIcon(_ button: NSButton, _ symbol: String) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: button.title)
        button.imagePosition = .imageLeading; button.toolTip = button.title
    }
    func button(_ title: String, _ action: Selector, primary: Bool = false) -> NSButton {
        let result = FlatButton(title: CqsLocale.t(title), target: self, action: action)
        result.isBordered = false; result.font = .systemFont(ofSize: 14, weight: .regular)
        result.alignment = .center
        result.wantsLayer = true; result.layer?.cornerRadius = 4
        result.layer?.borderWidth = primary ? 0 : 1
        result.layer?.borderColor = NSColor(calibratedWhite: 0.85, alpha: 1).cgColor
        result.layer?.backgroundColor = (primary ? green : .white).cgColor
        result.contentTintColor = primary ? .white : .labelColor
        result.heightAnchor.constraint(equalToConstant: 36).isActive = true
        result.widthAnchor.constraint(greaterThanOrEqualToConstant: max(title == "Save" ? 64 : 80, result.intrinsicContentSize.width)).isActive = true
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
        lifecycle("smokeTest entered")
        do {
            let output = URL(fileURLWithPath: CommandLine.arguments.last!); try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for key in ["Credits", "Quota remaining", "Plan and dates", "Monthly daily average", "Display choices"] {
                guard let translations = CqsLocale.catalog[key], translations.count == 2 else { preconditionFailure("Missing canonical locale key: \(key)") }
                for (index, language) in ["zh-CN", "zh-TW"].enumerated() {
                    let field = NSTextField(labelWithString: key)
                    CqsLocale.language = language; CqsLocale.apply(field)
                    precondition(field.stringValue == translations[index])
                    CqsLocale.language = "en"; CqsLocale.apply(field)
                    precondition(field.stringValue == key, "Reverse translation must retain canonical key: \(key)")
                }
            }
            for language in ["en", "zh-CN", "zh-TW"] {
                CqsLocale.language = language; languagePicker.selectItem(at: language == "en" ? 0 : language == "zh-CN" ? 1 : 2)
                for action in [showAuthorizationHelp, showStatus, showDisplay, showSettings, showData, showHelp, showAbout] {
                    fputs("UI smoke: switching page, language \(language)\n", stderr)
                    action(); lifecycle("smoke page \(page) built; localization begin")
                    CqsLocale.apply(window.contentView!); lifecycle("smoke page \(page) layout begin")
                    window.contentView!.layoutSubtreeIfNeeded(); lifecycle("smoke page \(page) display begin")
                    window.displayIfNeeded()
                    assertV3Geometry()
                    fputs("UI smoke: laid out \(page)\n", stderr)
                    precondition(abs(body.frame.minY - body.superview!.bounds.minY) < 2, "Page content is not top aligned")
                    if page == "subscription" { plan.selectItem(at: 2); enabled.state = .on; updateFields(); save(); precondition(!dirty && page == "subscription" && saveButton?.isEnabled == false) }
                    if page == "display" { saveDisplay(); precondition(!dirty && page == "display") }
                    let view = window.contentView!
                    func findTitle(_ parent: NSView) -> NSView? { if parent.identifier?.rawValue == "brand-title" { return parent }; for child in parent.subviews { if let match = findTitle(child) { return match } }; return nil }
                    guard let brand = findTitle(view), !brand.isHiddenOrHasHiddenAncestor, brand.bounds.width > 150, brand.bounds.height > 10 else { throw NSError(domain: "CQS", code: 4, userInfo: [NSLocalizedDescriptionKey: "Brand header is hidden or clipped"]) }
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(page + "-" + language + ".png"))
                    for size in [NSSize(width: 820, height: 520), NSSize(width: 1024, height: 700), NSSize(width: 1440, height: 1000)] {
                        window.setContentSize(size); adaptLayout(); window.displayIfNeeded(); assertV3Geometry()
                        if let last = body.arrangedSubviews.last {
                            let target = last.convert(last.bounds, to: pageDocument)
                            pageDocument.scrollToVisible(target)
                            precondition(pageScroll.contentView.documentVisibleRect.intersects(target), "Last page action must be reachable without hiding the footer")
                            pageScroll.contentView.scroll(to: .zero)
                        }
                        if size.width == 1440 && size.height == 1000 {
                            precondition(pageDocument.bounds.height <= pageScroll.contentView.bounds.height + 1, "Tall windows must not need vertical scrolling")
                        }
                        let resized = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                        view.cacheDisplay(in: view.bounds, to: resized)
                        try resized.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(page + "-" + language + "-\(Int(size.width))x\(Int(size.height)).png"))
                    }
                    window.setContentSize(NSSize(width: 1184, height: 820)); adaptLayout()
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
                precondition(abs(body.frame.minY - body.superview!.bounds.minY) < 2, "Failure refresh shifted content")
                let ownerView = window.contentView!, ownerBitmap = ownerView.bitmapImageRepForCachingDisplay(in: ownerView.bounds)!
                ownerView.cacheDisplay(in: ownerView.bounds, to: ownerBitmap)
                try ownerBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("owner-failure-" + language + ".png"))
                let now = Date().timeIntervalSince1970 * 1000
                try write("membership.json", ["enabled": true, "plan": "pro", "tier": "100", "purchaseDate": "2026-11-13", "date": "2026-12-13", "kind": "renewal"])
                try write("browser-state.json", ["schema": 1, "generatedAt": now, "quotaAt": now, "usageAt": now, "windows": [["minutes": 300, "remaining": 62, "resetsAt": now + 3600000],["minutes": 10080, "remaining": 37]], "daily": ["date": dateString(Calendar.current.date(byAdding: .day, value: -1, to: Date())!), "value": 202650000], "monthAverage":125350000, "week":96900000, "lifetime": 3008200000, "creditBalance": "162", "resetCredits": 3])
                stage = "mounted"; errorText = ""; page = ""; showStatus(); tick(); window.contentView!.layoutSubtreeIfNeeded()
                assertV3Geometry()
                rows[1].stringValue = CqsLocale.t("Synced"); rows[2].stringValue = CqsLocale.t("Synced"); rows[3].stringValue = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                precondition(overviewValues.count == 11 && overviewTracks.count == 4)
                precondition(abs(overviewValues["weekly"]!.convert(overviewValues["weekly"]!.bounds, to: window.contentView).minY - overviewValues["lifetime"]!.convert(overviewValues["lifetime"]!.bounds, to: window.contentView).minY) < 1)
                precondition(!metricFields[2].stringValue.contains("\n") && !metricCaptions[2].stringValue.isEmpty)
                precondition(metricFields[4].stringValue == "3.01B" && metricCaptions[2].font!.pointSize < metricFields[2].font!.pointSize)
                let connectedView = window.contentView!, connectedBitmap = connectedView.bitmapImageRepForCachingDisplay(in: connectedView.bounds)!
                connectedView.cacheDisplay(in: connectedView.bounds, to: connectedBitmap)
                try connectedBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("connected-fixture-" + language + ".png"))
                try write("browser-state.json", ["generatedAt": now, "quotaAt": now, "usageAt": now, "windows": []])
                updateMetrics(true); rows[1].stringValue = CqsLocale.t("Not returned"); rows[2].stringValue = CqsLocale.t("Not returned")
                precondition(metricFields.allSatisfy { $0.stringValue == "--" } && metricCaptions[2].stringValue == CqsLocale.t("Not returned"))
                let emptyBitmap = connectedView.bitmapImageRepForCachingDisplay(in: connectedView.bounds)!
                connectedView.cacheDisplay(in: connectedView.bounds, to: emptyBitmap)
                try emptyBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("empty-fixture-" + language + ".png"))
                updateMetrics(false); precondition(metricCaptions[2].stringValue == CqsLocale.t("Not connected") && metricFields[2].stringValue == "--")
                for (name, choices) in [("all-eleven", [:]), ("none", Dictionary(uniqueKeysWithValues: MetricPresentation.keys.map { ($0, false) })), ("tokens-only", Dictionary(uniqueKeysWithValues: MetricPresentation.keys.map { ($0, ["daily", "average", "weekly", "lifetime"].contains($0)) }))] as [(String, [String: Bool])] {
                    try write("display.json", choices); page = ""; showStatus(); updateMetrics(true)
                    window.contentView!.layoutSubtreeIfNeeded()
                    assertV3Geometry()
                    precondition(overviewValues.count == (name == "none" ? 0 : name == "tokens-only" ? 4 : 11))
                    let bitmap = connectedView.bitmapImageRepForCachingDisplay(in: connectedView.bounds)!; connectedView.cacheDisplay(in: connectedView.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("choices-" + name + "-" + language + ".png"))
                }
                try write("display.json", [:])
                for (name, member) in [("blank", [:]), ("manual", ["enabled": true, "plan": "pro", "purchaseDate": "2026-01-31", "date": "2026-02-28", "kind": "renewal"]), ("estimated", ["enabled": true, "plan": "plus", "purchaseDate": "2026-01-31", "monthlyEstimate": true])] as [(String, [String: Any])] {
                    try write("membership.json", member); page = ""; showSettings(); window.contentView!.layoutSubtreeIfNeeded()
                    assertV3Geometry()
                    if name == "blank" { precondition(purchase.stringValue.isEmpty && next.stringValue.isEmpty) }
                    if name == "estimated" {
                        precondition(next.stringValue == "2026-02-28" && !next.isEnabled)
                        purchase.picker.dateValue = date("2024-02-29")!; purchase.changed()
                        mode.selectItem(at: 3); updateFields(); precondition(next.stringValue == "2025-02-28")
                        save()
                        let savedMember = read("membership.json")
                        precondition(savedMember["date"] as? String == "2025-02-28" && savedMember["purchaseDate"] as? String == "2024-02-29")
                        precondition(savedMember["plan"] as? String == "plus", "Date edits must preserve the plan")
                        purchase.presence.state = .off; purchase.changed(); precondition(next.stringValue.isEmpty)
                        save(); precondition(read("membership.json")["purchaseDate"] == nil && read("membership.json")["date"] == nil)
                        page = ""; showSettings(); precondition(purchase.stringValue.isEmpty && next.stringValue.isEmpty)
                    }
                    let bitmap = connectedView.bitmapImageRepForCachingDisplay(in: connectedView.bounds)!; connectedView.cacheDisplay(in: connectedView.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("dates-" + name + "-" + language + ".png"))
                }
                stage = "stopped"; errorText = ""; page = ""
            }
            page = ""; stage = "starting"; showStatus()
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                updateConnectionAnimation(); precondition(connectionTimer != nil)
                connectionTimer?.fire(); precondition(headline.stringValue.hasSuffix("."))
                connectionAnimationStart = Date().addingTimeInterval(-61); connectionTimer?.fire(); precondition(connectionTimer == nil)
                updateConnectionAnimation(); precondition(connectionTimer == nil, "Animation must not restart after its time budget")
            }
            updateConnectionAnimation(reducedMotion: true); precondition(connectionTimer == nil)
            stage = "mounted"; tick(); precondition(connectionTimer == nil)
            for language in ["en", "zh-CN", "zh-TW"] {
                CqsLocale.language = language
                for code in ["E_PLAN_UNKNOWN", "E_DESKTOP_UNAVAILABLE", "E_MANUAL_LOCK", "E_BUSY", "E_CONFIG_INVALID", "E_ALREADY_ATTEMPTED", "E_NATIVE_PLAN_TIMEOUT"] {
                    planFailure = code
                    precondition(!planFailureMessage().contains("E_"))
                    if language != "en" { precondition(!planFailureMessage().contains("Choose a plan")) }
                }
            }
            let backup = try SettingsTransfer.exportData(runtime); try SettingsTransfer.restore(backup, at: runtime)
            do { _ = try SettingsTransfer.checked(Data("{\"auth.json\":{\"token\":\"do-not-import\"}}".utf8)); fatalError("Unknown settings accepted") } catch {}
            print("PASS: native Mac pages, three languages, save persistence and settings boundary; synthetic fixture only")
            NSApp.terminate(nil)
        } catch { fputs("UI smoke failed: \(error)\n", stderr); exit(1) }
    }
    func assertV3Geometry() {
        func find(_ id: String, in view: NSView) -> NSView? {
            if view.identifier?.rawValue == id { return view }
            for child in view.subviews { if let found = find(id, in: child) { return found } }
            return nil
        }
        let content = window.contentView!
        precondition(window.styleMask.contains(.resizable) && window.contentMinSize.width == 820)
        precondition(abs(languagePicker.bounds.height - 36) < 1 && languagePicker.bounds.width >= languagePicker.intrinsicContentSize.width - 1 && languagePicker.bounds.width < 148, "Language popup should tightly fit its icon, label and chevron")
        if let footer = find("window-footer", in: content) {
            let f = footer.convert(footer.bounds, to: content), viewport = pageScroll.convert(pageScroll.bounds, to: content)
            precondition(content.bounds.contains(f) && viewport.minY >= f.maxY - 1, "Footer must stay visible outside scroll content")
        }
        precondition(abs(pageDocument.bounds.width - pageScroll.contentView.bounds.width) < 2, "No horizontal scrolling")
        precondition(pageDocument.bounds.height + 1 >= body.frame.maxY, "Document must include the entire page")
        func checkBounds(_ view: NSView) {
            guard !view.isHiddenOrHasHiddenAncestor else { return }
            if view is NSControl || view is OptionalDatePicker {
                let rect = view.convert(view.bounds, to: pageDocument)
                precondition(rect.minX >= -1 && rect.maxX <= pageDocument.bounds.width + 1, "Control outside page: \(view)")
                precondition(rect.maxY <= pageDocument.bounds.height + 1, "Control clipped below document")
                if view is NSControl { return }
            }
            view.subviews.forEach { checkBounds($0) }
        }
        checkBounds(body)
        if page == "overview", let charts = find("overview-charts", in: content) as? NSStackView {
            precondition(abs(charts.bounds.width - body.bounds.width) < 1, "Charts must span the full content width")
            if let quotas = find("quota-column", in: charts), let tokens = find("token-column", in: charts) {
                let q = quotas.convert(quotas.bounds, to: charts), t = tokens.convert(tokens.bounds, to: charts)
                if charts.orientation == .horizontal {
                    precondition(abs(q.width + t.width + 38 - charts.bounds.width) < 2, "Columns must fill available width")
                    precondition(abs(t.minX - q.maxX - 38) < 2, "Columns must not overlap")
                } else {
                    precondition(abs(q.width - charts.bounds.width) < 2 && abs(t.width - charts.bounds.width) < 2, "Narrow charts must use full-width rows")
                    precondition(q.maxY <= t.minY + 1 || t.maxY <= q.minY + 1, "Stacked charts must not overlap")
                }
                lifecycle("geometry quota=\(q.width), tokens=\(t.width), gutter=\(t.minX - q.maxX)")
            }
            func checkLabels(_ view: NSView) {
                if view.identifier?.rawValue == "plot-label", let field = view as? NSTextField {
                    let width = (field.stringValue as NSString).size(withAttributes: [.font: field.font!]).width
                    precondition(field.bounds.width >= ceil(width) + 2, "Localized plot label is clipped: \(field.stringValue)")
                }
                view.subviews.forEach { checkLabels($0) }
            }
            checkLabels(charts)
        }
        if page == "subscription" {
            precondition(plan.bounds.width > 200 && plan.bounds.width <= body.bounds.width, "Plan popup must fit available width")
            for control in [plan, tier, mode] { precondition(abs(control.bounds.height - 36) < 1, "Plan/date popups must be 36px high") }
            for control in [purchase, next] { precondition(abs(control.bounds.height - 36) < 1 && control.bounds.width >= 260, "Native date pickers must fit adaptive form tracks") }
            lifecycle("geometry plan=\(plan.bounds.width)x\(plan.bounds.height), date=\(purchase.bounds.width)x\(purchase.bounds.height)")
        }
        if let button = find("open-codex", in: content) {
            guard let bitmap = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { preconditionFailure("Cannot inspect Open Codex icon pixels") }
            button.cacheDisplay(in: button.bounds, to: bitmap)
            let sx = CGFloat(bitmap.pixelsWide) / button.bounds.width, sy = CGFloat(bitmap.pixelsHigh) / button.bounds.height
            let x0 = Int(12 * sx), x1 = min(bitmap.pixelsWide, Int(28 * sx))
            let y0 = max(0, Int((button.bounds.height / 2 - 8) * sy)), y1 = min(bitmap.pixelsHigh, Int((button.bounds.height / 2 + 8) * sy))
            var whitePixels = 0
            for y in y0..<y1 { for x in x0..<x1 {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.8 && color.redComponent > 0.85 && color.greenComponent > 0.85 && color.blueComponent > 0.85 { whitePixels += 1 }
            } }
            precondition(whitePixels > 4, "Open Codex symbol must render white on the blue button")
        }
    }
    func clear() {
        stopConnectionAnimation(); responsiveLayouts.removeAll(); restartButton = nil
        for view in body.arrangedSubviews { body.removeArrangedSubview(view); view.removeFromSuperview() }
        pageScroll.contentView.scroll(to: .zero)
    }
    func responsive(_ stack: NSStackView, threshold: CGFloat, ratio: CGFloat? = nil) {
        var constraints: [NSLayoutConstraint] = []
        var previous: Bool?
        let layout: (CGFloat) -> Void = { width in
            let narrow = width < threshold
            guard previous != narrow else { return }; previous = narrow
            NSLayoutConstraint.deactivate(constraints); constraints = []
            stack.orientation = narrow ? .vertical : .horizontal
            stack.alignment = narrow ? .leading : .top
            stack.distribution = narrow || ratio != nil ? .fill : .fillEqually
            let children = stack.arrangedSubviews
            if narrow || children.count == 1 {
                constraints = children.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) }
            } else if let ratio = ratio, children.count == 2 {
                constraints = [children[0].widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: ratio, constant: -stack.spacing * ratio), children[1].widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 1 - ratio, constant: -stack.spacing * (1 - ratio))]
            }
            NSLayoutConstraint.activate(constraints)
        }
        responsiveLayouts.append(layout)
        layout(max(0, window.contentView!.bounds.width - 256))
    }
    func windowDidResize(_ notification: Notification) { adaptLayout() }
    func adaptLayout() {
        let width = max(0, window.contentView!.bounds.width - 256)
        responsiveLayouts.forEach { $0(width) }
        window.contentView?.layoutSubtreeIfNeeded()
    }
    func stopConnectionAnimation() { connectionTimer?.invalidate(); connectionTimer = nil; connectionAnimationStart = nil; connectionFrame = 0 }
    func updateConnectionAnimation(reducedMotion: Bool? = nil) {
        let connecting = page == "overview" && !runtimeIssue && !["failed", "stopped"].contains(stage) && !stage.hasPrefix("mounted")
        guard connecting, window.isVisible, !window.isMiniaturized, !(reducedMotion ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) else { stopConnectionAnimation(); return }
        // One finite animation per connection attempt; polling must not restart it.
        if connectionAnimationStart == nil { connectionAnimationStart = Date() }
        guard Date().timeIntervalSince(connectionAnimationStart!) < 60 else { connectionTimer?.invalidate(); connectionTimer = nil; return }
        guard connectionTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard self.window.isVisible, !self.window.isMiniaturized, self.page == "overview", !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                  !self.runtimeIssue, !["failed", "stopped"].contains(self.stage), !self.stage.hasPrefix("mounted"),
                  let start = self.connectionAnimationStart, Date().timeIntervalSince(start) < 60 else { self.connectionTimer?.invalidate(); self.connectionTimer = nil; return }
            self.connectionFrame = (self.connectionFrame + 1) % 4
            self.headline.stringValue = CqsLocale.t(self.stage == "checking" ? "Checking runtime" : "Connecting") + String(repeating: ".", count: self.connectionFrame)
        }
        timer.tolerance = 0.1; RunLoop.main.add(timer, forMode: .common); connectionTimer = timer
    }
    func present() {
        lifecycle("present localization begin")
        CqsLocale.apply(window.contentView!)
        purchase.localize("Purchase date"); next.localize("Renewal / expiry")
        languagePicker.invalidateIntrinsicContentSize()
        updateNotice?.setAccessibilityLabel(CqsLocale.t("Update available"))
        updateNotice?.toolTip = CqsLocale.t("Update available")
        if updateAvailable && updateProcess == nil { updateButton.title = CqsLocale.t("Update available") + " " + availableVersion }
        adaptLayout()
        lifecycle("present localization returned; activation begin")
        NSApp.activate(ignoringOtherApps: true)
        lifecycle("present activation returned; window ordering begin")
        window.makeKeyAndOrderFront(nil)
        updateConnectionAnimation()
        lifecycle("present window ordering returned")
    }
    @objc func openGitHub() { NSWorkspace.shared.open(CqsLocale.repository) }
    @objc func changeLanguage() {
        guard resolvePendingEdits() else { languagePicker.selectItem(at: CqsLocale.language == "en" ? 0 : CqsLocale.language == "zh-CN" ? 1 : 2); return }
        CqsLocale.language = ["en","zh-CN","zh-TW"][languagePicker.indexOfSelectedItem]
        UserDefaults.standard.set(CqsLocale.language, forKey: "cqs-language")
        try? Data(("\"" + CqsLocale.language + "\"").utf8).write(to: runtime.appendingPathComponent("language.json"), options: .atomic)
        CqsLocale.apply(window.contentView!)
        for item in statusItem.menu?.items ?? [] { item.title = CqsLocale.t(item.title) }
        let previous = page; page = ""
        switch previous {
        case "subscription": showSettings()
        case "display": showDisplay()
        case "data": showData()
        case "help": showHelp()
        case "about": showAbout()
        case "authorization": showAuthorizationHelp()
        default: showStatus()
        }
    }
    func line(_ label: String, _ value: NSView, into target: NSStackView? = nil) {
        let row = NSStackView(); row.spacing = 20; let key = NSTextField(labelWithString: CqsLocale.t(label)); key.textColor = .secondaryLabelColor
        key.font = .systemFont(ofSize: 13, weight: .regular)
        if let field = value as? NSTextField { field.font = .systemFont(ofSize: 13, weight: .regular) }
        key.widthAnchor.constraint(equalToConstant: 130).isActive = true; row.addArrangedSubview(key); row.addArrangedSubview(value); (target ?? body).addArrangedSubview(row)
        if value is NSPopUpButton { value.widthAnchor.constraint(equalToConstant: 340).isActive = true }
    }
    @objc func showStatus() {
        lifecycle("overview enter (page=\(page), stage=\(stage))")
        if page == "overview" { tick(); present(); return }
        guard beginPage("overview") else { return }; showingSettings = false; rows = []
        lifecycle("overview hierarchy cleared; header begin")
        let top = NSStackView(); top.alignment = .centerY
        let title = label("Usage overview", size: 22); top.addArrangedSubview(title)
        let gap = NSView(); top.addArrangedSubview(gap); gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headline.font = .systemFont(ofSize: 13, weight: .regular); top.addArrangedSubview(headline)
        let statusWidth = ceil(((CqsLocale.t("Checking runtime") + "...") as NSString).size(withAttributes: [.font: headline.font!]).width)
        headline.widthAnchor.constraint(greaterThanOrEqualToConstant: statusWidth).isActive = true
        body.addArrangedSubview(top); top.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        detail.font = .systemFont(ofSize: 13, weight: .regular); detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 0
        if runtimeIssue { authorizationButtons() }
        if errorText.trimmingCharacters(in: .whitespacesAndNewlines) == "E_RESTART_REQUIRED" {
            restartButton = button("Save work, restart and connect", #selector(confirmRestart), primary: true)
            body.addArrangedSubview(restartButton!)
        }
        body.spacing = stage.hasPrefix("mounted") && !runtimeIssue && errorText.isEmpty ? 20 : 8
        let statusLines = NSStackView(); statusLines.orientation = .horizontal; statusLines.alignment = .top; statusLines.distribution = .fillEqually; statusLines.spacing = 16
        for title in ["Client","Quota data","Token data","Last sync"] {
            let cell = NSStackView(); cell.orientation = .vertical; cell.alignment = .leading; cell.spacing = 4
            let label = NSTextField(labelWithString: CqsLocale.t(title)); label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor
            let field = NSTextField(labelWithString: "--"); field.font = .systemFont(ofSize: 11); field.lineBreakMode = .byTruncatingTail
            cell.addArrangedSubview(label); cell.addArrangedSubview(field); rows.append(field); statusLines.addArrangedSubview(cell)
        }
        overviewValues = [:]; overviewCaptions = [:]; overviewTracks = [:]; dailyLabel = nil; dailyNote = nil
        let display = read("display.json")
        overviewSignature = MetricPresentation.keys.map { display[$0] as? Bool == false ? "0" : "1" }.joined() + (stage.hasPrefix("mounted") ? "mounted" : "waiting")
        func has(_ key: String) -> Bool { display[key] as? Bool != false }
        let charts = NSStackView(); charts.orientation = .horizontal; charts.alignment = .top; charts.spacing = 38; charts.distribution = .fill; charts.identifier = NSUserInterfaceItemIdentifier("overview-charts")
        let quotas = column(spacing: 22), tokens = column(spacing: 22)
        quotas.identifier = NSUserInterfaceItemIdentifier("quota-column"); tokens.identifier = NSUserInterfaceItemIdentifier("token-column")
        func metric(_ key: String, _ name: String, size: CGFloat = 23) -> NSStackView {
            let cell = column(spacing: 7)
            cell.addArrangedSubview(label(name, size: 12, muted: true))
            let value = label("--", size: size); value.lineBreakMode = .byTruncatingTail
            let caption = label("Not returned", size: 11, muted: true)
            caption.lineBreakMode = .byTruncatingTail
            cell.addArrangedSubview(value); cell.addArrangedSubview(caption)
            overviewValues[key] = value; overviewCaptions[key] = caption
            return cell
        }
        if has("short") || has("week") {
            quotas.addArrangedSubview(label("Quota remaining", size: 14))
            for (key, name) in [("short", "5-hour remaining"), ("week", "Weekly remaining")] where has(key) {
                let cell = metric(key, name, size: 26)
                let caption = overviewCaptions[key]!; cell.removeArrangedSubview(caption); caption.removeFromSuperview()
                let track = QuotaTrack(); track.heightAnchor.constraint(equalToConstant: 9).isActive = true
                if key == "week" { track.tone = NSColor(calibratedRed: 0.14, green: 0.52, blue: 0.43, alpha: 1) }
                cell.addArrangedSubview(track); track.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true; overviewTracks[key] = track
                let axis = axisRow(["0", "50", "100%"]); cell.addArrangedSubview(axis); axis.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
                cell.addArrangedSubview(caption); quotas.addArrangedSubview(cell); cell.widthAnchor.constraint(equalTo: quotas.widthAnchor).isActive = true
            }
            charts.addArrangedSubview(quotas)
        }
        lifecycle("overview quota hierarchy built")
        if has("daily") || has("average") {
            let heading = column(spacing: 8); heading.addArrangedSubview(label("Daily vs monthly daily average", size: 14)); heading.addArrangedSubview(label("Shared scale - M tokens", size: 11, muted: true)); tokens.addArrangedSubview(heading)
            for (key, name) in [("daily", "Daily tokens"), ("average", "Monthly daily average")] where has(key) {
                let row = NSStackView(); row.spacing = 12; row.alignment = .centerY; row.distribution = .fill
                let nameField = label(name, size: 12); nameField.identifier = NSUserInterfaceItemIdentifier("plot-label")
                let labelWidth = max(100, ceil((CqsLocale.t("Monthly daily average") as NSString).size(withAttributes: [.font: nameField.font!]).width) + 4)
                nameField.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
                nameField.setContentCompressionResistancePriority(.required, for: .horizontal); row.addArrangedSubview(nameField)
                if key == "daily" { dailyLabel = nameField }
                let track = QuotaTrack(); track.plot = true; track.heightAnchor.constraint(equalToConstant: 14).isActive = true
                track.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal); track.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                track.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
                if key == "average" { track.tone = NSColor(calibratedRed: 0.14, green: 0.52, blue: 0.43, alpha: 1) }
                row.addArrangedSubview(track); overviewTracks[key] = track; overviewCaptions[key] = label("Not returned", size: 11, muted: true)
                let value = label("--", size: 15); value.alignment = .right; value.widthAnchor.constraint(equalToConstant: 76).isActive = true; row.addArrangedSubview(value); overviewValues[key] = value
                tokens.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true
            }
            let axis = axisRow(["0", "--", "--"]); axis.identifier = NSUserInterfaceItemIdentifier("token-axis")
            let labelWidth = max(100, ceil((CqsLocale.t("Monthly daily average") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width) + 4)
            let axisFrame = NSView(); tokens.addArrangedSubview(axisFrame); axisFrame.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true; axisFrame.heightAnchor.constraint(equalToConstant: 14).isActive = true
            axis.translatesAutoresizingMaskIntoConstraints = false; axisFrame.addSubview(axis)
            NSLayoutConstraint.activate([axis.leadingAnchor.constraint(equalTo: axisFrame.leadingAnchor, constant: labelWidth + 12), axis.trailingAnchor.constraint(equalTo: axisFrame.trailingAnchor, constant: -88), axis.topAnchor.constraint(equalTo: axisFrame.topAnchor), axis.bottomAnchor.constraint(equalTo: axisFrame.bottomAnchor)])
            let note = label("", size: 11, muted: true); tokens.addArrangedSubview(note); dailyNote = note
        }
        let tail = NSStackView(); tail.distribution = .fillEqually; tail.spacing = 20
        for (key, name) in [("weekly", "Weekly tokens"), ("lifetime", "Lifetime tokens")] where has(key) { tail.addArrangedSubview(metric(key, name)) }
        if !tail.arrangedSubviews.isEmpty { let line = separator(); tokens.addArrangedSubview(line); line.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true; tokens.addArrangedSubview(tail); tail.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true }
        if !tokens.arrangedSubviews.isEmpty { charts.addArrangedSubview(tokens) }
        if !charts.arrangedSubviews.isEmpty {
            body.addArrangedSubview(charts); charts.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
            responsive(charts, threshold: 900, ratio: 0.87 / 1.87)
        }
        lifecycle("overview chart hierarchy built")
        let auxiliary = NSStackView(); auxiliary.distribution = .fillEqually; auxiliary.spacing = 24
        auxiliary.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        auxiliary.wantsLayer = true; auxiliary.layer?.backgroundColor = NSColor(calibratedWhite: 0.973, alpha: 1).cgColor
        for (key, name) in [("reset", "Quota reset date"), ("resetCredits", "Reset count"), ("credits", "Credits")] where has(key) { auxiliary.addArrangedSubview(metric(key, name, size: 16)) }
        if !auxiliary.arrangedSubviews.isEmpty { body.addArrangedSubview(auxiliary); auxiliary.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true }
        let meta = NSStackView(); meta.spacing = 26
        for (key, name) in [("plan", "Plan"), ("renewal", "Renewal date")] where has(key) {
            let row = NSStackView(); row.spacing = 8; row.addArrangedSubview(label(name, size: 12, muted: true)); let value = label("--", size: 12, muted: true); row.addArrangedSubview(value); overviewValues[key] = value; meta.addArrangedSubview(row)
        }
        if !meta.arrangedSubviews.isEmpty { let line = separator(); body.addArrangedSubview(line); line.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true; body.addArrangedSubview(meta) }
        if overviewValues.isEmpty { paragraph("No metrics selected."); body.addArrangedSubview(button("Display choices", #selector(showDisplay))) }
        let source = label("Usage: local CLI. Plan: desktop detection or manual record.", size: 12, muted: true); source.identifier = NSUserInterfaceItemIdentifier("source-status"); source.lineBreakMode = .byTruncatingTail; body.addArrangedSubview(source); source.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        body.addArrangedSubview(detail)
        // Cross-view constraints require a common ancestor before activation.
        precondition(detail.isDescendant(of: body), "Overview detail must be attached before width activation")
        detail.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        lifecycle("overview detail attached; width constraint activated")
        metricFields = ["short", "week", "daily", "weekly", "lifetime", "average"].map { overviewValues[$0] ?? label("--", size: 15) }
        metricCaptions = ["short", "week", "daily", "weekly", "lifetime", "average"].map { overviewCaptions[$0] ?? label("Not returned", size: 11) }
        // The fixed status fields remain available as accessibility/tooltips, without another visual block.
        top.toolTip = rows.map { $0.stringValue }.joined(separator: " / ")
        lifecycle("overview hierarchy complete; tick begin")
        tick(); lifecycle("overview tick returned; present begin")
        present(); lifecycle("overview present returned")
    }
    func label(_ text: String, size: CGFloat, muted: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: CqsLocale.t(text)); field.font = .systemFont(ofSize: max(12, size), weight: .regular); field.textColor = muted ? .secondaryLabelColor : .labelColor; return field
    }
    func column(spacing: CGFloat) -> NSStackView { let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.distribution = .fill; stack.spacing = spacing; return stack }
    func separator() -> NSView { let view = NSBox(); view.boxType = .separator; view.heightAnchor.constraint(equalToConstant: 1).isActive = true; return view }
    func axisRow(_ values: [String]) -> NSStackView {
        let row = NSStackView(); row.distribution = .fillEqually
        for (index, value) in values.enumerated() { let field = label(value, size: 10, muted: true); field.alignment = index == 0 ? .left : index == 1 ? .center : .right; row.addArrangedSubview(field) }; return row
    }
    @objc func showSettings() {
        guard beginPage("subscription") else { return }; showingSettings = true; let member = read("membership.json")
        familyEdited = false; planSource = member["planSource"] as? String ?? "manual"
        heading("Plan and dates"); paragraph("No sign-up or purchase for this tool. Records are optional.")
        enabled.state = member["enabled"] as? Bool == true ? .on : .off; enabled.target = self; enabled.action = #selector(updateFields)
        plan.removeAllItems(); plan.addItems(withTitles: ["Free", "Go", "Plus", "Pro", "Business", "Enterprise", "Edu", CqsLocale.t("Other / unknown")])
        let index = ["free", "go", "plus", "pro", "business", "enterprise", "edu", "other"].firstIndex(of: member["plan"] as? String ?? "other") ?? 7
        plan.selectItem(at: index); plan.target = self; plan.action = #selector(planChanged)
        for field in [purchase, next] { field.onChange = { [weak self] in self?.updateFields() } }
        purchase.stringValue = member["purchaseDate"] as? String ?? ""; next.stringValue = member["date"] as? String ?? ""
        tier.removeAllItems(); tier.addItems(withTitles: [CqsLocale.t("Other / unknown"), "100", "200", "500", "Standard", "Premium"])
        tier.selectItem(at: ["unknown", "100", "200", "500", "standard", "premium"].firstIndex(of: member["tier"] as? String ?? "unknown") ?? 0); tier.target = self; tier.action = #selector(tierChanged)
        mode.removeAllItems(); mode.addItems(withTitles: [CqsLocale.t("Monthly estimate"), CqsLocale.t("Set renewal date"), CqsLocale.t("Set expiry date")]); mode.selectItem(at: member["monthlyEstimate"] as? Bool == true ? 0 : member["kind"] as? String == "expiry" ? 2 : 1); mode.target = self; mode.action = #selector(updateFields)
        mode.addItem(withTitle: CqsLocale.t("Business annual estimate")); if member["annualEstimate"] as? Bool == true { mode.selectItem(at: 3) }
        let form = column(spacing: 18)
        let planRow = NSStackView(); planRow.spacing = 12; planRow.alignment = .bottom; planRow.distribution = .fill
        let planField = formField("Plan badge", plan); planRow.addArrangedSubview(planField)
        let detect = button("Detect plan", #selector(detectPlan)); detectPlanButton = detect; detect.isEnabled = planProcess == nil
        detect.setContentHuggingPriority(.required, for: .horizontal); detect.setContentCompressionResistancePriority(.required, for: .horizontal)
        let detectWidth = max(80, detect.intrinsicContentSize.width); detect.widthAnchor.constraint(equalToConstant: detectWidth).isActive = true; planRow.addArrangedSubview(detect)
        form.addArrangedSubview(planRow); planRow.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        planField.widthAnchor.constraint(equalTo: form.widthAnchor, constant: -detectWidth - 12).isActive = true
        planSourceField.font = .systemFont(ofSize: 13); planSourceField.textColor = .secondaryLabelColor
        planSourceField.usesSingleLineMode = false; planSourceField.lineBreakMode = .byWordWrapping; planSourceField.cell?.wraps = true
        form.addArrangedSubview(planSourceField); planSourceField.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        for fields in [[formField("Specific tier (manual, optional)", tier), formField("Date type", mode)], [formField("Purchase date", purchase), formField("Renewal / expiry", next)]] {
            let row = NSStackView(); row.distribution = .fillEqually; row.spacing = 24; fields.forEach { row.addArrangedSubview($0) }; form.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
            responsive(row, threshold: 640)
        }
        body.addArrangedSubview(form); form.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true; updateFields()
        paragraph("Dates are optional. Detection never changes dates. Leave blank to hide.")
        body.addArrangedSubview(enabled)
        let commands = NSStackView(); commands.spacing = 8
        saveButton = button("Save", #selector(save), primary: true); commands.addArrangedSubview(saveButton!); body.addArrangedSubview(commands); editingReady = true; present()
    }
    @objc func updateFields() {
        markDirty()
        let estimated = mode.indexOfSelectedItem == 0 || mode.indexOfSelectedItem == 3
        if estimated {
            next.stringValue = MetricPresentation.renewal(["enabled": true, "purchaseDate": purchase.stringValue, "monthlyEstimate": mode.indexOfSelectedItem == 0, "annualEstimate": mode.indexOfSelectedItem == 3]) ?? ""
        }
        next.isEnabled = !estimated
        planSourceField.stringValue = planProcess != nil ? CqsLocale.t("Detecting plan. The official Codex usage panel may open briefly.") : planFailure.isEmpty ? CqsLocale.t(planSource == "desktop" ? "Desktop detection" : "Manual record (locked)") : planFailureMessage()
    }
    func formField(_ title: String, _ control: NSView) -> NSStackView {
        let field = column(spacing: 8); field.addArrangedSubview(label(title, size: 13)); field.addArrangedSubview(control)
        control.widthAnchor.constraint(equalTo: field.widthAnchor).isActive = true
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if let popup = control as? NSPopUpButton { popup.font = .systemFont(ofSize: 14, weight: .regular); popup.isBordered = false; popup.heightAnchor.constraint(equalToConstant: 36).isActive = true }
        return field
    }
    @objc func planChanged() { familyEdited = true; planSource = "manual"; updateFields() }
    @objc func tierChanged() { markDirty() }
    func controlTextDidChange(_ obj: Notification) { markDirty() }
    @objc func detectPlan() {
        guard resolvePendingEdits() else { return }
        let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Detect plan from Codex desktop?"); prompt.informativeText = CqsLocale.t("Detection replaces the plan family only. Manual tier and dates stay unchanged.") + "\n\n" + CqsLocale.t("The official Codex usage panel may open briefly during detection."); prompt.addButton(withTitle: CqsLocale.t("Cancel")); prompt.addButton(withTitle: CqsLocale.t("Detect plan"))
        if prompt.runModal() == .alertSecondButtonReturn { runPlanDetection("detect") }
    }
    func runPlanDetection(_ operation: String) {
        guard planProcess == nil, !CommandLine.arguments.contains("--ui-smoke") else { return }
        let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node"); process.arguments = [root.appendingPathComponent("src/plan.mjs").path, operation, root.path]
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"; environment["LC_ALL"] = "en_US.UTF-8"; process.environment = environment
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice; planProcess = process
        var timedOut = false
        detectPlanButton?.isEnabled = false
        if page == "subscription" { planSourceField.stringValue = CqsLocale.t("Detecting plan. The official Codex usage panel may open briefly.") }
        if page == "overview" { detail.stringValue = CqsLocale.t("Detecting plan. The official Codex usage panel may open briefly."); detail.isHidden = false }
        process.terminationHandler = { [weak self] child in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let self = self else { return }; self.planTimeout?.invalidate(); self.planTimeout = nil; self.planProcess = nil; self.detectPlanButton?.isEnabled = true
                if timedOut { self.planFailure = "E_NATIVE_PLAN_TIMEOUT"; self.showPlanFailure(operation); return }
                // Parse UTF-8 JSON bytes directly: localized output must not depend on a shell codepage.
                let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                if result?["detected"] as? Bool == true {
                    self.planFailure = ""
                    if self.page == "subscription" && !self.dirty { self.page = ""; self.showSettings() }
                    if self.page == "overview" { self.updateMetrics(self.stage.hasPrefix("mounted")) }
                } else {
                    self.planFailure = result?["error"] as? String ?? "E_DESKTOP_UNAVAILABLE"
                    self.showPlanFailure(operation)
                }
            }
        }
        do {
            try process.run()
            let timeout = Timer(timeInterval: 30, repeats: false) { [weak self, weak process] _ in
                guard let self = self, let process = process, self.planProcess === process, process.isRunning else { return }
                timedOut = true; process.terminate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak process] in
                    // Escalation is restricted to our own detector child, never the official client.
                    guard let self = self, let process = process, self.planProcess === process, process.isRunning else { return }
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
            }
            timeout.tolerance = 0.1; RunLoop.main.add(timeout, forMode: .common); planTimeout = timeout
        } catch { planProcess = nil; detectPlanButton?.isEnabled = true; planFailure = "E_DESKTOP_UNAVAILABLE"; showPlanFailure(operation) }
    }
    func planFailureMessage() -> String {
        let reason: String
        switch planFailure {
        case "E_NATIVE_PLAN_TIMEOUT": reason = "Plan detection timed out."
        case "E_MANUAL_LOCK": reason = "Your manual plan is locked and was kept."
        case "E_PLAN_UNKNOWN": reason = "Codex did not return a recognized plan."
        case "E_ALREADY_ATTEMPTED": reason = "Automatic detection has already been attempted."
        case "E_BUSY", "E_CONFIG_CHANGED": reason = "Settings are being changed. Try detection again."
        case "E_CONFIG_INVALID", "E_WRITE_FAILED": reason = "Plan settings could not be read or saved safely."
        default: reason = "Codex desktop is not available for plan detection."
        }
        return CqsLocale.t(reason) + " " + CqsLocale.t("Choose a plan manually in Plan and dates, or retry Detect plan. Your tier and dates are unchanged.")
    }
    func showPlanFailure(_ operation: String) {
        if page == "subscription" { planSourceField.stringValue = planFailureMessage() }
        if page == "overview" { detail.stringValue = planFailureMessage(); detail.isHidden = false }
        if operation == "detect" { alert(planFailureMessage()) }
    }
    @objc func showDisplay() {
        guard beginPage("display") else { return }; showingSettings = true; displayChecks = []
        let values = read("display.json"), stack = NSStackView(); stack.orientation = .horizontal; stack.alignment = .top; stack.spacing = 24; stack.distribution = .fillEqually
        heading("Display choices")
        let toolbar = NSStackView(); toolbar.spacing = 12; toolbar.distribution = .fill; toolbar.alignment = .centerY
        toolbar.addArrangedSubview(selectionCount)
        let toolbarGap = NSView(); toolbarGap.setContentHuggingPriority(.defaultLow, for: .horizontal); toolbarGap.setContentCompressionResistancePriority(.defaultLow, for: .horizontal); toolbar.addArrangedSubview(toolbarGap)
        toolbar.addArrangedSubview(button("Select all", #selector(selectAll))); toolbar.addArrangedSubview(button("Clear selection", #selector(selectNone))); body.addArrangedSubview(toolbar)
        toolbar.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true; toolbar.heightAnchor.constraint(equalToConstant: 52).isActive = true; body.setCustomSpacing(30, after: toolbar)
        let groups: [(String, [(String, String)])] = [("Plan and dates", [("plan", "Plan badge"), ("renewal", "Renewal date")]), ("Quota and resets", [("short", "5-hour remaining"), ("week", "Weekly remaining"), ("reset", "Quota reset date"), ("resetCredits", "Reset count"), ("credits", "Credits")]), ("Token usage", [("daily", "Daily tokens"), ("average", "Monthly daily average"), ("weekly", "Weekly tokens"), ("lifetime", "Lifetime tokens")])]
        for (name, items) in groups {
            let group = column(spacing: 0); let groupTitle = label(name, size: 14); group.addArrangedSubview(groupTitle); group.setCustomSpacing(14, after: groupTitle); stack.addArrangedSubview(group)
            for (key, title) in items {
                let check = NSButton(checkboxWithTitle: CqsLocale.t(title), target: self, action: #selector(selectionChanged)); check.font = .systemFont(ofSize: 13, weight: .regular)
                check.heightAnchor.constraint(equalToConstant: 38).isActive = true
                check.state = values[key] as? Bool == false ? .off : .on; displayChecks.append((key, check)); group.addArrangedSubview(check)
            }
        }
        body.addArrangedSubview(stack); stack.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        responsive(stack, threshold: 700)
        updateSelectionCount()
        paragraph("One selection applies to the Codex sidebar, overview and browser panel.")
        paragraph("Official controls have priority. Scroll first; collapse only when space is very limited.")
        paragraph("Changes apply automatically while connected. No reconnect is needed.")
        saveButton = button("Save", #selector(saveDisplay), primary: true); body.addArrangedSubview(saveButton!); editingReady = true; present()
    }
    @objc func saveDisplay() {
        do { var value = try readForSave("display.json"); for (key, check) in displayChecks { value[key] = check.state == .on }; try write("display.json", value); saved() }
        catch { alert(error.localizedDescription) }
    }
    func updateSelectionCount() { selectionCount.stringValue = CqsLocale.t("Selected") + " \(displayChecks.filter { $0.1.state == .on }.count) / 11" }
    @objc func selectionChanged() { markDirty(); updateSelectionCount() }
    @objc func selectAll() { displayChecks.forEach { $0.1.state = .on }; selectionChanged() }
    @objc func selectNone() { displayChecks.forEach { $0.1.state = .off }; selectionChanged() }
    func paragraph(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: CqsLocale.t(text)); label.font = .systemFont(ofSize: 13)
        body.addArrangedSubview(label); label.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
    }
    func heading(_ text: String) {
        let label = NSTextField(labelWithString: CqsLocale.t(text)); label.font = .systemFont(ofSize: 22, weight: .regular); body.addArrangedSubview(label)
    }
    @objc func showHelp() {
        guard beginPage("help") else { return }; showingSettings = true; heading("Diagnostics")
        if let issue = updateRecoveryMessage() { paragraph(issue) }
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
            var report: [String: Any] = ["version": Bootstrap.releaseVersion ?? "--", "platform": "macOS", "stage": stage, "connectionCode": allowedCodes.contains(code) ? code : "", "runtimeReady": runtimeReady, "runtimeIssue": runtimeIssue, "monitorRunning": child?.isRunning == true, "exportedAt": ISO8601DateFormatter().string(from: Date())]
            let transaction = read("updates/transaction.json")
            if let updateStage = transaction["stage"] as? String, ["failed", "rolled-back", "needs-attention", "complete"].contains(updateStage) {
                report["updateStage"] = updateStage
                if let updateCode = transaction["code"] as? String, updateCode.range(of: #"^E_[A-Z0-9_]{1,64}$"#, options: .regularExpression) != nil { report["updateCode"] = updateCode }
            }
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
        body.addArrangedSubview(button("Show application in Finder", #selector(revealApplication)))
        body.addArrangedSubview(updateButton); present()
    }
    @objc func skip() { enabled.state = .off; save() }
    @objc func save() {
        let purchaseText = purchase.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), nextText = next.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (purchaseText.isEmpty || date(purchaseText) != nil) && (nextText.isEmpty || date(nextText) != nil) else { alert(CqsLocale.t("Enter a valid date as yyyy-MM-dd, or leave blank.")); return }
        if !purchaseText.isEmpty && !nextText.isEmpty && nextText < purchaseText { alert(CqsLocale.t("Renewal/expiry date cannot precede purchase date.")); return }
        let lock = runtime.appendingPathComponent("membership.json.lock")
        let fd = Darwin.open(lock.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600))
        guard fd >= 0 else { alert(CqsLocale.t("E_BUSY")); return }
        defer { Darwin.close(fd); try? FileManager.default.removeItem(at: lock) }
        var member: [String: Any]
        do { member = try readForSave("membership.json") } catch { alert(CqsLocale.t("E_CONFIG_INVALID")); return }
        member["enabled"] = enabled.state == .on
        if familyEdited { member["plan"] = ["free", "go", "plus", "pro", "business", "enterprise", "edu", "other"][plan.indexOfSelectedItem]; member["planSource"] = "manual"; member["manualOverride"] = true }
        let selectedTier = ["unknown", "100", "200", "500", "standard", "premium"][tier.indexOfSelectedItem]
        if selectedTier != "unknown" || member["tier"] != nil { member["tier"] = selectedTier }
        if purchaseText.isEmpty { member.removeValue(forKey: "purchaseDate") } else { member["purchaseDate"] = purchaseText }
        if nextText.isEmpty { member.removeValue(forKey: "date") } else { member["date"] = nextText }
        member["kind"] = mode.indexOfSelectedItem == 2 ? "expiry" : "renewal"
        member["monthlyEstimate"] = mode.indexOfSelectedItem == 0; member["annualEstimate"] = mode.indexOfSelectedItem == 3; member["estimated"] = mode.indexOfSelectedItem == 0 || mode.indexOfSelectedItem == 3
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
                var prefs = self.read("preferences.json"); if (prefs["macGuideVersion"] as? String ?? "").isEmpty { prefs["macGuideVersion"] = "1" }
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
        if mounted && !autoPlanAttempted { autoPlanAttempted = true; runPlanDetection("auto") }
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
        if let issue = updateRecoveryMessage() { detail.stringValue = issue }
        detail.isHidden = mounted && feedbackUntil <= Date() && updateRecoveryMessage() == nil
        if mounted && !planFailure.isEmpty && feedbackUntil <= Date() && updateRecoveryMessage() == nil { detail.stringValue = planFailureMessage(); detail.isHidden = false }
        if mounted && planProcess != nil && updateRecoveryMessage() == nil { detail.stringValue = CqsLocale.t("Detecting plan. The official Codex usage panel may open briefly."); detail.isHidden = false }
        updateConnectionAnimation()
        updateMetrics(mounted)
        CqsLocale.apply(window.contentView!)
    }
    func updateMetrics(_ connected: Bool) {
        let display = read("display.json")
        let signature = MetricPresentation.keys.map { display[$0] as? Bool == false ? "0" : "1" }.joined() + (stage.hasPrefix("mounted") ? "mounted" : "waiting")
        if page == "overview" && signature != overviewSignature { page = ""; showStatus(); return }
        let snapshot = read("browser-state.json")
        let values = MetricPresentation.overview(snapshot, display: display, member: read("membership.json"), connected: connected, now: Date().timeIntervalSince1970 * 1000)
        let daily = snapshot["daily"] as? [String: Any] ?? [:]
        let maximum = MetricPresentation.plotMaximum([values["daily"]?.value != "--" ? MetricPresentation.number(daily["value"]) : nil, values["average"]?.value != "--" ? MetricPresentation.number(snapshot["monthAverage"]) : nil].compactMap { $0 })
        for (key, value) in values {
            overviewValues[key]?.stringValue = CqsLocale.t(value.value)
            overviewValues[key]?.textColor = value.value == "--" ? .secondaryLabelColor : .labelColor
            overviewValues[key]?.toolTip = CqsLocale.t(value.caption)
            overviewValues[key]?.setAccessibilityLabel(CqsLocale.t(value.caption) + " " + value.value)
            overviewCaptions[key]?.stringValue = CqsLocale.t(value.caption)
            if ["short", "week"].contains(key) {
                overviewTracks[key]?.fraction = value.fraction
                if let fraction = value.fraction { overviewCaptions[key]?.stringValue = CqsLocale.t("Remaining") + String(format: " %g%%", fraction * 100) + " / " + CqsLocale.t("Used") + String(format: " %g%%", (1 - fraction) * 100) }
            } else if ["daily", "average"].contains(key) {
                let raw = key == "daily" ? daily["value"] : snapshot["monthAverage"]
                overviewTracks[key]?.fraction = value.value == "--" ? nil : MetricPresentation.number(raw).map { $0 / maximum }
            }
        }
        // Keep the daily date separate from the compact count, including older available records.
        metricCaptions[2].stringValue = CqsLocale.t(values["daily"]?.caption ?? "Not returned")
        if let daily = values["daily"] {
            let isDate = MetricPresentation.recordDate(daily.caption) != nil
            dailyLabel?.stringValue = CqsLocale.t(isDate ? "Latest available" : ["Today", "Yesterday"].contains(daily.caption) ? daily.caption : "Daily tokens")
            dailyNote?.stringValue = isDate ? CqsLocale.t("Latest available") + " " + daily.caption : daily.value == "--" ? CqsLocale.t(daily.caption) : ""
        }
        func updateAxis(_ view: NSView) {
            if view.identifier?.rawValue == "token-axis", let stack = view as? NSStackView { let labels = stack.arrangedSubviews.compactMap { $0 as? NSTextField }; if labels.count == 3 { labels[1].stringValue = MetricPresentation.count(maximum / 2); labels[2].stringValue = MetricPresentation.count(maximum) } }
            if view.identifier?.rawValue == "source-status", let field = view as? NSTextField { field.stringValue = CqsLocale.t("Usage: local CLI. Plan: desktop detection or manual record.") + "  /  " + CqsLocale.t("Last sync") + " " + (rows.last?.stringValue ?? "--") }
            view.subviews.forEach { updateAxis($0) }
        }
        updateAxis(body)
    }
    func updateRecoveryMessage() -> String? {
        let transaction = read("updates/transaction.json")
        guard let stage = transaction["stage"] as? String, ["failed", "rolled-back", "needs-attention"].contains(stage) else { return nil }
        let key = ["failed": "Update failed. Your current app remains available.", "rolled-back": "Update rolled back. Previous app restored.", "needs-attention": "Update needs attention. Open Diagnostics."][stage]!
        let code = transaction["code"] as? String ?? ""
        let safeCode = code.range(of: #"^E_[A-Z0-9_]{1,64}$"#, options: .regularExpression) != nil ? code : ""
        return CqsLocale.t(key) + (safeCode.isEmpty ? "" : "\n" + CqsLocale.t(safeCode))
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
        guard resolvePendingEdits() else { return }
        if let probe = runtimeProbe { runtimeProbe = nil; probe.cancel() }
        guard child?.isRunning == true else { NSApp.terminate(nil); return }
        do { try Data("stop".utf8).write(to: runtime.appendingPathComponent("background-stop.request"), options: .atomic); stopping = true
            stopTimer?.invalidate(); stopTimer = Timer.scheduledTimer(withTimeInterval: 40, repeats: false) { [weak self] _ in
                guard let self = self, self.child?.isRunning == true else { return }; self.stopping = false; self.alert(CqsLocale.t("Startup checks are still running. Try exiting later. Codex will not be force-closed."))
            }
        } catch { alert(error.localizedDescription) }
    }
    @objc func checkUpdates() { runUpdate("check") }
    func updateFailureMessage(_ code: String?) -> String {
        guard let code = code, let english = MetricPresentation.updateFailureReasons[code] else { return CqsLocale.t("Update check failed. Please try again later.") }
        let localized = CqsLocale.t(code)
        return localized == code ? CqsLocale.t(english) : localized
    }
    func runUpdate(_ operation: String) {
        guard updateProcess == nil else { return }
        if operation == "prepare" && !resolvePendingEdits() { return }
        let operationStarted = Date().timeIntervalSince1970 * 1000
        let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node")
        process.arguments = [root.appendingPathComponent("src/update.mjs").path, operation, root.path, Bundle.main.bundleURL.path, String(ProcessInfo.processInfo.processIdentifier)]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        updateButton.isEnabled = false; updateNotice.isEnabled = false; updateButton.title = CqsLocale.t(operation == "download" ? "Downloading update..." : "Checking for updates...")
        updateProcess = process
        if operation == "prepare" {
            let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 96), styleMask: [.titled], backing: .buffered, defer: false)
            sheet.title = CqsLocale.t("Preparing update...")
            let spinner = NSProgressIndicator(frame: NSRect(x: 24, y: 28, width: 24, height: 24)); spinner.style = .spinning; spinner.startAnimation(nil); sheet.contentView?.addSubview(spinner)
            let message = label("Preparing update...", size: 13); message.frame = NSRect(x: 64, y: 30, width: 240, height: 20); sheet.contentView?.addSubview(message)
            updatePreparationSheet = sheet; window.beginSheet(sheet)
        }
        process.terminationHandler = { [weak self] child in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let self = self else { return }; self.updateProcess = nil; self.updateButton.isEnabled = true; self.updateNotice.isEnabled = true; self.updateButton.title = CqsLocale.t("Check for updates")
                self.endUpdatePreparation()
                let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                if child.terminationStatus != 0 || parsed == nil || parsed?["error"] != nil {
                    let code = MetricPresentation.updateFailureCode(parsed) ?? MetricPresentation.persistedUpdateFailureCode(self.read("updates/last-error.json"), since: operationStarted)
                    if operation != "auto" { self.alert(self.updateFailureMessage(code)) }
                    return
                }
                guard let result = parsed else { return }
                if operation == "prepare" {
                    guard MetricPresentation.strictBoolean(result["prepared"]) == true else { self.alert(CqsLocale.t("Update preparation failed. The app will stay open.")); return }
                    self.stop(); return
                }
                guard let available = MetricPresentation.strictBoolean(result["available"]) else {
                    if operation != "auto" { self.alert(self.updateFailureMessage("E_UPDATE_METADATA")) }
                    return
                }
                self.updateAvailable = available
                self.availableVersion = result["version"] as? String ?? ""
                self.updateNotice.isHidden = !self.updateAvailable
                guard self.updateAvailable else { if operation != "auto" { self.alert(CqsLocale.t("You are up to date.")) }; return }
                self.updateButton.title = CqsLocale.t("Update available") + " " + self.availableVersion
                if operation == "auto" { return }
                let ready = MetricPresentation.strictBoolean(result["ready"]) == true
                let dialog = NSAlert(); dialog.messageText = CqsLocale.t(ready ? "Restart the companion to install the verified update? Codex stays open." : "Download this update in the background?")
                dialog.informativeText = (result["version"] as? String ?? "") + "\n\n" + (result["notes"] as? String ?? "")
                dialog.addButton(withTitle: CqsLocale.t("Cancel")); dialog.addButton(withTitle: CqsLocale.t("Continue"))
                if dialog.runModal() == .alertSecondButtonReturn { self.runUpdate(ready ? "prepare" : "download") }
            }
        }
        do { try process.run() } catch { endUpdatePreparation(); updateProcess = nil; updateButton.isEnabled = true; updateNotice.isEnabled = true; updateButton.title = CqsLocale.t("Check for updates"); if operation != "auto" { alert(updateFailureMessage("E_UPDATE_CONFIGURATION")) } }
    }
    func endUpdatePreparation() { if let sheet = updatePreparationSheet { window.endSheet(sheet); sheet.orderOut(nil); updatePreparationSheet = nil } }
    func resolvePendingEdits() -> Bool {
        guard dirty else { return true }
        let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Save pending changes?")
        prompt.addButton(withTitle: CqsLocale.t("Save")); prompt.addButton(withTitle: CqsLocale.t("Discard")); prompt.addButton(withTitle: CqsLocale.t("Stay"))
        switch prompt.runModal() {
        case .alertFirstButtonReturn: if page == "subscription" { save() } else if page == "display" { saveDisplay() }; return !dirty
        case .alertSecondButtonReturn:
            dirty = false; let previous = page; page = ""
            if previous == "subscription" { showSettings() } else if previous == "display" { showDisplay() } else { page = previous }
            return true
        default: return false
        }
    }
    func alert(_ text: String) {
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke alert: \(text)\n", stderr); exit(1) }
        let a = NSAlert(); a.messageText = "Codex Quota Sidebar"; a.informativeText = text; a.runModal()
    }
    func windowDidMiniaturize(_ notification: Notification) { stopConnectionAnimation() }
    func windowDidDeminiaturize(_ notification: Notification) { updateConnectionAnimation() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { stopConnectionAnimation(); sender.orderOut(nil); return false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { guard resolvePendingEdits() else { return .terminateCancel }; if child?.isRunning == true { stop(); return .terminateCancel }; return .terminateNow }
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
