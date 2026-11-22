import AppKit
import UserNotifications
import Darwin

private let fills = NSMapTable<NSView, NSColor>.weakToStrongObjects()
private func fill(_ view: NSView, _ color: NSColor) {
    fills.setObject(color, forKey: view)
    (view.window?.effectiveAppearance ?? NSApp.effectiveAppearance).performAsCurrentDrawingAppearance {
        view.layer?.backgroundColor = color.cgColor
    }
}
final class PageDocument: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        for case let view as NSView in fills.keyEnumerator().allObjects {
            if let color = fills.object(forKey: view) { effectiveAppearance.performAsCurrentDrawingAppearance { view.layer?.backgroundColor = color.cgColor }; view.needsDisplay = true }
        }
    }
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
        picker.presentsCalendarOverlay = true; picker.font = BoardType.body
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


private enum BoardType {
    static let title = NSFont.systemFont(ofSize: 20, weight: .semibold)
    static let section = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let body = NSFont.systemFont(ofSize: 13)
    static let command = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let note = NSFont.systemFont(ofSize: 12)
    static let numberNote = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    static let caption = NSFont.systemFont(ofSize: 11)
    static let metric = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    static let largeMetric = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
    static let gauge = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
}

enum CommandRole { case primary, secondary, neutral, quiet }

final class FlatButton: NSButton {
    var role: CommandRole?
    static let commandHeight: CGFloat = 32
    private var ink: NSColor {
        guard isEnabled else { return .disabledControlTextColor }
        switch role {
        case .primary: return .white
        case .secondary: return .linkColor
        case .quiet: return .secondaryLabelColor
        case .neutral: return .labelColor
        case nil: return contentTintColor ?? .labelColor
        }
    }
    override var intrinsicContentSize: NSSize {
        let size = (title as NSString).size(withAttributes: [.font: font ?? BoardType.body])
        return NSSize(width: ceil(size.width) + (image == nil ? 24 : 46), height: role == nil ? 36 : Self.commandHeight)
    }
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        if let role = role {
            let background: NSColor
            switch role {
            case .primary: background = NSColor(srgbRed: 0.15, green: 0.35, blue: 0.77, alpha: 1)
            case .secondary: background = NSColor.systemBlue.withAlphaComponent(0.13)
            case .neutral: background = NSColor.labelColor.withAlphaComponent(0.09)
            case .quiet: background = .clear
            }
            (isEnabled ? background : NSColor.labelColor.withAlphaComponent(0.05)).setFill(); shape.fill()
        }
        if isHighlighted && isEnabled { NSColor.labelColor.withAlphaComponent(0.12).setFill(); shape.fill() }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? BoardType.body, .foregroundColor: ink, .paragraphStyle: paragraph]
        let height = (title as NSString).size(withAttributes: attributes).height
        let inset: CGFloat = image == nil ? 12 : 34
        if let image = image { drawSymbol(image, in: NSRect(x: 12, y: (bounds.height - 16) / 2, width: 16, height: 16), color: ink) }
        (title as NSString).draw(in: NSRect(x: inset, y: (bounds.height - height) / 2, width: bounds.width - inset - 12, height: height), withAttributes: attributes)
    }
}

// Native shell only. The shared Node core remains responsible for quota data.
final class QuotaTrack: NSView {
    var fraction: Double? { didSet { needsDisplay = true } }
    var tone = NSColor(calibratedRed: 0.157, green: 0.384, blue: 0.827, alpha: 1)
    var plot = false
    var dial = false
    override func draw(_ dirtyRect: NSRect) {
        if dial {
            let radius = max(0, min((bounds.width-14)/2, bounds.height-10))
            let center = NSPoint(x: bounds.midX, y: 5)
            func arc(_ angle: Double, _ color: NSColor) {
                guard angle > 0 else { return }
                let p = NSBezierPath()
                p.appendArc(withCenter: center, radius: radius, startAngle: 180, endAngle: CGFloat(180-angle), clockwise: true)
                p.lineWidth = 7; p.lineCapStyle = .round; color.setStroke(); p.stroke()
            }
            arc(180, NSColor.labelColor.withAlphaComponent(0.14))
            if let n = fraction { arc(180 * min(1, max(0,n)), tone) }
            return
        }
        let y = plot ? (bounds.height - 2) / 2 : 0
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        NSRect(x: 0, y: y, width: bounds.width, height: plot ? 2 : bounds.height).fill()
        if let value = fraction {
            tone.setFill(); let x = bounds.width * min(1, max(0, value))
            NSRect(x: 0, y: y, width: x, height: plot ? 2 : bounds.height).fill()
            if plot { NSBezierPath(ovalIn: NSRect(x: min(bounds.width - 12, max(0, x - 6)), y: (bounds.height - 12) / 2, width: 12, height: 12)).fill() }
        }
    }
}

final class MonthTrendView: NSView {
    var days: [Double?] = []
    private var missingDays = Set<Int>()
    var month = ""
    var selected: Int? = nil
    var cumulative = false
    var changed: (() -> Void)?
    let blue = NSColor(srgbRed: 0.18, green: 0.42, blue: 0.86, alpha: 1)
    override var acceptsFirstResponder: Bool { true }
    func update(_ month: String, _ days: [Double?], missing: Set<Int> = []) {
        missingDays = missing
        if self.month != month || selected.map({ !days.indices.contains($0) || days[$0] == nil }) != false {
            selected = days.lastIndex(where: { $0 != nil })
        }
        self.month = month; self.days = days; needsDisplay = true; changed?()
    }
    func value(_ i: Int) -> Double? {
        guard let n = days[i] else { return nil }
        return cumulative ? days.prefix(i+1).compactMap { $0 }.reduce(0,+) : n
    }
    var reading: String {
        guard let i = selected, days.indices.contains(i), let n = value(i) else { return CqsLocale.t("No usage records") }
        let note = missingDays.contains(i) ? " · " + CqsLocale.t("No usage records") : ""
        return month + String(format: "-%02d   ",i+1) + MetricPresentation.count(n) + " Token" + note
    }
    func choose(_ i: Int) {
        guard days.indices.contains(i), days[i] != nil else { return }
        selected = i; needsDisplay = true; changed?()
    }
    override func keyDown(with event: NSEvent) {
        let step = event.keyCode == 123 ? -1 : event.keyCode == 124 ? 1 : 0
        guard step != 0, let selected = selected else { super.keyDown(with: event); return }
        var i = selected + step
        while days.indices.contains(i) && days[i] == nil { i += step }
        choose(i)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let x = convert(event.locationInWindow, from:nil).x
        let i = Int(((x-49)/max(1,bounds.width-67)*CGFloat(max(1,days.count-1))).rounded())
        choose(i)
    }
    override func draw(_ dirtyRect: NSRect) {
        let line = NSColor.separatorColor
        let bottom: CGFloat = 24, top = max(bottom+1,bounds.height-15)
        let maxValue = max(1,MetricPresentation.plotMaximum(days.indices.compactMap { value($0) }))
        let text: [NSAttributedString.Key: Any] = [.font: BoardType.caption, .foregroundColor: NSColor.secondaryLabelColor]
        func x(_ i: Int) -> CGFloat { 49+max(1,bounds.width-67)*CGFloat(i)/CGFloat(max(1,days.count-1)) }
        func segment(_ a: NSPoint,_ b: NSPoint,_ color: NSColor,_ width: CGFloat = 1) {
            let p = NSBezierPath();p.move(to:a);p.line(to:b);p.lineWidth=width;color.setStroke();p.stroke()
        }
        for i in 0...4 {
            let y = bottom+(top-bottom)*CGFloat(i)/4
            segment(NSPoint(x:49,y:y),NSPoint(x:bounds.width-18,y:y),line)
            (MetricPresentation.count(maxValue*Double(i)/4) as NSString).draw(at:NSPoint(x:8,y:y-6),withAttributes:text)
        }
        let stride = max(1,(days.count+3)/4)
        for i in days.indices where i % stride == 0 || i == days.count-1 && i % stride >= 2 {
            ("\(i+1)" as NSString).draw(at:NSPoint(x:x(i)-4,y:5),withAttributes:text)
        }
        guard let selected = selected else {
            (CqsLocale.t("No usage records") as NSString).draw(at:NSPoint(x:max(5,bounds.midX-48),y:bounds.midY),withAttributes:text);return
        }
        segment(NSPoint(x:x(selected),y:bottom),NSPoint(x:x(selected),y:top),line)
        var previous: NSPoint?
        for i in days.indices {
            guard let v = value(i) else { previous=nil;continue }
            let next = NSPoint(x:x(i),y:bottom+CGFloat(v/maxValue)*(top-bottom))
            if let p = previous { segment(p,next,blue,2) }
            let r: CGFloat = i==selected ? 4 : 2.5
            blue.setFill();NSBezierPath(ovalIn:NSRect(x:next.x-r,y:next.y-r,width:r*2,height:r*2)).fill()
            previous=next
        }
    }
}

final class QuotaApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate, UNUserNotificationCenterDelegate {
    weak var weeklyThresholdControl: NSPopUpButton?
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
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
    let updateProgress = NSProgressIndicator()
    let updateProgressText = NSTextField(labelWithString: "")
    var updateProgressTimer: Timer?
    var updateAvailable = false
    var availableVersion = ""
    var headline = NSTextField(labelWithString: CqsLocale.t("Connecting"))
    let toolbarTitle = NSTextField(labelWithString: "")
    var detail = NSTextField(wrappingLabelWithString: CqsLocale.t("Waiting for client and data."))
    var rows: [NSTextField] = []
    var bulkButton: NSButton?
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
        headline.isHidden = next != "overview"
        for (key, control) in navigationButtons {
            fill(control, key == next ? NSColor.controlAccentColor.withAlphaComponent(0.16) : .clear)
            control.contentTintColor = key == next ? .controlAccentColor : .labelColor
        }
        clear(); return true
    }
    @objc func markDirty() { if editingReady { dirty = true } }
    func saved() {
        dirty = false
        guard let control = saveButton else { return }
        control.title = CqsLocale.t("Saved successfully"); control.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak control] in
            guard let control = control else { return }; control.title = CqsLocale.t("Save"); control.isEnabled = true
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
    var monthTrend: MonthTrendView?
    var monthStamp: NSTextField?
    var planProcess: Process?
    var planTimeout: Timer?
    weak var detectPlanButton: NSButton?
    var autoPlanAttempted = false
    var planSource = "manual"
    var familyEdited = false
    let planSourceField = NSTextField(labelWithString: "")
    let planSummary = NSTextField(labelWithString: "")
    private let initialSize = NSSize(width: 1184, height: 594)
    let tier = NSPopUpButton(frame: .zero, pullsDown: false)
    let selectionCount = NSTextField(labelWithString: "")
    let selectionMeter: NSProgressIndicator = {
        let meter = NSProgressIndicator()
        meter.style = .bar; meter.isIndeterminate = false; meter.controlSize = .small
        meter.widthAnchor.constraint(equalToConstant: 90).isActive = true
        return meter
    }()
    let languagePicker = NSPopUpButton(frame: .zero, pullsDown: false)
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
    let plan = NSPopUpButton(frame: .zero, pullsDown: false)
    let purchase = OptionalDatePicker()
    let mode = NSPopUpButton(frame: .zero, pullsDown: false)
    let next = OptionalDatePicker()
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
        if Bundle.main.bundleURL.pathExtension == "app" { UNUserNotificationCenter.current().delegate = self }
        if CommandLine.arguments.contains("--ui-smoke") { fputs("UI smoke: launch\n", stderr) }
        guard checkInstallLocation() else { NSApp.terminate(nil); return }
        do { try Bootstrap.install(at: root); try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true) }
        catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        if UserDefaults.standard.string(forKey: "cqs-language") == nil, let data = try? Data(contentsOf: runtime.appendingPathComponent("language.json")), let saved = (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? String, ["en", "zh-CN", "zh-TW"].contains(saved) { UserDefaults.standard.set(saved, forKey: "cqs-language"); CqsLocale.language = saved }
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: initialSize), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 820, height: 520)
        window.collectionBehavior = [.fullScreenPrimary]
        window.title = "AI Usage Monitor"; window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        applyAppearance()
        window.backgroundColor = .controlBackgroundColor
        window.contentView!.wantsLayer = true
        fill(window.contentView!, .controlBackgroundColor)
        let container = NSStackView(); container.orientation = .vertical; container.alignment = .leading; container.spacing = 0
        container.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        container.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(container)
        NSLayoutConstraint.activate([container.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor), container.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor), container.topAnchor.constraint(equalTo: window.contentView!.topAnchor), container.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)])
        let header = NSStackView(); header.spacing = 16; header.distribution = .fill; header.alignment = .centerY
        header.heightAnchor.constraint(equalToConstant: 62).isActive = true
        let pageInset: CGFloat = 25
        header.edgeInsets = NSEdgeInsets(top: 12, left: pageInset, bottom: 12, right: pageInset)
        let icon = NSButton(image: NSImage(contentsOf: root.appendingPathComponent("assets/cqs-128.png")) ?? NSImage(), target: self, action: #selector(openGitHub))
        icon.title = ""; icon.isBordered = false; icon.imagePosition = .imageOnly; icon.imageScaling = .scaleProportionallyDown
        icon.toolTip = CqsLocale.t("Visit GitHub project"); icon.setAccessibilityLabel(CqsLocale.t("Visit GitHub project"))
        icon.widthAnchor.constraint(equalToConstant: 31).isActive = true; icon.heightAnchor.constraint(equalToConstant: 31).isActive = true
        let words = NSStackView(); words.orientation = .vertical; words.alignment = .leading; words.spacing = 4
        let title = NSTextField(labelWithString: "AI Usage Monitor"); title.font = BoardType.command
        title.identifier = NSUserInterfaceItemIdentifier("brand-title")
        let version = NSTextField(labelWithString: "by KEFEN"); version.textColor = .secondaryLabelColor; version.font = BoardType.caption
        words.addArrangedSubview(title); words.addArrangedSubview(version)
        let brand = NSStackView(views: [icon, words]); brand.alignment = .centerY; brand.spacing = 8
        brand.heightAnchor.constraint(equalToConstant: 53).isActive = true
        toolbarTitle.font = BoardType.title
        toolbarTitle.lineBreakMode = .byTruncatingTail
        headline.font = BoardType.note
        headline.lineBreakMode = .byTruncatingTail
        header.addArrangedSubview(toolbarTitle); header.addArrangedSubview(headline)
        let headerGap = NSView(); header.addArrangedSubview(headerGap); headerGap.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerGap.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        header.setVisibilityPriority(.mustHold, for: toolbarTitle)
        updateButton = button("Check for updates", #selector(checkUpdates))
        let downloadIcon = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil) ?? NSImage(named: NSImage.networkName) ?? NSImage()
        updateNotice = NSButton(image: downloadIcon.withSymbolConfiguration(.init(pointSize: 18, weight: .semibold)) ?? downloadIcon, target: self, action: #selector(checkUpdates))
        updateNotice.title = ""; updateNotice.alternateTitle = ""
        updateNotice.identifier = NSUserInterfaceItemIdentifier("update-notice")
        updateNotice.bezelStyle = .regularSquare; updateNotice.isBordered = false; updateNotice.imagePosition = .imageOnly
        updateNotice.contentTintColor = .controlAccentColor
        updateNotice.wantsLayer = true; updateNotice.layer?.cornerRadius = 6
        updateNotice.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor
        updateNotice.setAccessibilityLabel(CqsLocale.t("Update available")); updateNotice.toolTip = CqsLocale.t("Update available")
        header.addArrangedSubview(updateNotice)
        updateNotice.widthAnchor.constraint(equalToConstant: 36).isActive = true
        updateNotice.heightAnchor.constraint(equalToConstant: 36).isActive = true
        updateNotice.isHidden = true
        updateProgress.style = .bar
        updateProgress.controlSize = .small
        updateProgress.minValue = 0; updateProgress.maxValue = 100
        updateProgress.widthAnchor.constraint(equalToConstant: 180).isActive = true
        updateProgress.isHidden = true; updateProgressText.isHidden = true
        languagePicker.identifier = NSUserInterfaceItemIdentifier("language")
        languagePicker.font = BoardType.body; languagePicker.setAccessibilityLabel(CqsLocale.t("Language"))
        languagePicker.setContentHuggingPriority(.required, for: .horizontal)
        languagePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        languagePicker.addItems(withTitles: [CqsLocale.t("System"), "English", "简体中文", "繁體中文"])
        languagePicker.selectItem(at: CqsLocale.modes.firstIndex(of: CqsLocale.mode) ?? 0)
        languagePicker.target = self; languagePicker.action = #selector(changeLanguage)
        let divider = NSBox(); divider.boxType = .separator; divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let viewport = NSView()
        let right = NSStackView(views: [header, divider, viewport]); right.orientation = .vertical; right.spacing = 0
        right.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        divider.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        viewport.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        let split = NSView(); split.translatesAutoresizingMaskIntoConstraints = false
        let navigation = NSStackView(); navigation.orientation = .vertical; navigation.alignment = .leading; navigation.spacing = 4
        let sidebarMaterial = NSVisualEffectView()
        sidebarMaterial.material = .sidebar; sidebarMaterial.blendingMode = .behindWindow
        sidebarMaterial.translatesAutoresizingMaskIntoConstraints = false
        navigation.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 12, right: 10)
        navigation.addArrangedSubview(brand); navigation.setCustomSpacing(15, after: brand)
        for (key, label, action) in [("overview", "Usage overview", #selector(showStatus)), ("display", "Display choices", #selector(showDisplay)), ("subscription", "Plan and dates", #selector(showSettings)), ("data", "Data and settings", #selector(showData)), ("help", "Diagnostics", #selector(showHelp)), ("about", "About project", #selector(showAbout))] {
            if key == "about" { let space = NSView(); navigation.addArrangedSubview(space); space.setContentHuggingPriority(.defaultLow, for: .vertical) }
            let control = FlatButton(title: CqsLocale.t(label), target: self, action: action)
            control.isBordered = false; control.wantsLayer = true; control.layer?.cornerRadius = 6; control.alignment = .left
            control.font = BoardType.command
            for constraint in control.constraints where constraint.firstAttribute == .width { constraint.isActive = false }
            control.layer?.borderWidth = 0; control.layer?.backgroundColor = NSColor.clear.cgColor
            control.widthAnchor.constraint(equalToConstant: 156).isActive = true
            setIcon(control, ["overview": "chart.xyaxis.line", "display": "sidebar.left", "subscription": "calendar", "data": "slider.horizontal.3", "help": "lifepreserver", "about": "info.circle"][key]!)
            navigationButtons.append((key, control)); navigation.addArrangedSubview(control)
        }
        navigation.widthAnchor.constraint(equalToConstant: 176).isActive = true
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 14; body.distribution = .fill
        body.setContentHuggingPriority(.required, for: .vertical)
        navigation.translatesAutoresizingMaskIntoConstraints = false; body.translatesAutoresizingMaskIntoConstraints = false
        pageScroll.translatesAutoresizingMaskIntoConstraints = false
        pageScroll.drawsBackground = false; pageScroll.hasVerticalScroller = true; pageScroll.autohidesScrollers = true
        pageScroll.hasHorizontalScroller = false; pageScroll.horizontalScrollElasticity = .none; pageScroll.verticalScrollElasticity = .none
        pageScroll.scrollerStyle = .overlay
        pageDocument.translatesAutoresizingMaskIntoConstraints = true
        pageScroll.contentView.autoresizesSubviews = false
        pageScroll.documentView = pageDocument; pageDocument.addSubview(body)
        viewport.addSubview(pageScroll)
        split.addSubview(sidebarMaterial); split.addSubview(navigation); split.addSubview(right); container.addArrangedSubview(split)
        NSLayoutConstraint.activate([
            split.widthAnchor.constraint(equalTo: container.widthAnchor),
            sidebarMaterial.leadingAnchor.constraint(equalTo:navigation.leadingAnchor), sidebarMaterial.trailingAnchor.constraint(equalTo:navigation.trailingAnchor),
            sidebarMaterial.topAnchor.constraint(equalTo:navigation.topAnchor), sidebarMaterial.bottomAnchor.constraint(equalTo:navigation.bottomAnchor),
            navigation.leadingAnchor.constraint(equalTo: split.leadingAnchor),
            navigation.topAnchor.constraint(equalTo: split.topAnchor),
            navigation.bottomAnchor.constraint(equalTo: split.bottomAnchor),
            right.leadingAnchor.constraint(equalTo: navigation.trailingAnchor),
            right.trailingAnchor.constraint(equalTo: split.trailingAnchor),
            right.topAnchor.constraint(equalTo: split.topAnchor),
            right.bottomAnchor.constraint(equalTo: split.bottomAnchor),
            toolbarTitle.leadingAnchor.constraint(equalTo: pageScroll.leadingAnchor),
            pageScroll.leadingAnchor.constraint(equalTo: viewport.leadingAnchor, constant: pageInset),
            pageScroll.trailingAnchor.constraint(equalTo: viewport.trailingAnchor, constant: -pageInset),
            pageScroll.topAnchor.constraint(equalTo: viewport.topAnchor),
            pageScroll.bottomAnchor.constraint(equalTo: viewport.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: pageDocument.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: pageDocument.trailingAnchor),
            body.topAnchor.constraint(equalTo: pageDocument.topAnchor),
            body.bottomAnchor.constraint(lessThanOrEqualTo: pageDocument.bottomAnchor)
        ])
        body.edgeInsets = NSEdgeInsets(top: 19, left: 0, bottom: 16, right: 0)
        let build = NSTextField(labelWithString: "macOS " + (Bootstrap.releaseVersion ?? "--")); build.textColor = .secondaryLabelColor; build.font = BoardType.caption
        let quit = button("Exit software", #selector(stop), role: .quiet); setIcon(quit, "power")
        quit.toolTip = CqsLocale.t("Exit software"); quit.setAccessibilityLabel(quit.toolTip)
        quit.keyEquivalent = "q"; quit.keyEquivalentModifierMask = .command
        retry = button("Reconnect", #selector(reconnect), role: .secondary); setIcon(retry, "arrow.clockwise")
        retry.toolTip = CqsLocale.t("Reconnect"); retry.setAccessibilityLabel(retry.toolTip)
        retry.keyEquivalent = "r"; retry.keyEquivalentModifierMask = .command
        let open = button("Open Codex", #selector(openCodex), role: .primary); setIcon(open, "arrow.up.right")
        open.identifier = NSUserInterfaceItemIdentifier("open-codex")
        let commands = NSStackView(views: [quit, retry, open]); commands.spacing = 10; commands.alignment = .centerY
        commands.identifier = NSUserInterfaceItemIdentifier("window-commands")
        let boundary = separator()
        let spacer = NSView()
        let footer = NSStackView(views: [build, spacer, commands])
        footer.distribution = .fill; footer.alignment = .centerY
        footer.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: pageInset)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.setVisibilityPriority(.mustHold, for: commands)
        container.addArrangedSubview(boundary); container.addArrangedSubview(footer)
        NSLayoutConstraint.activate([boundary.widthAnchor.constraint(equalTo: container.widthAnchor),
            footer.widthAnchor.constraint(equalTo: container.widthAnchor), footer.heightAnchor.constraint(equalToConstant: 54)])
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(contentsOf: root.appendingPathComponent("assets/tray-template.png")) { image.isTemplate = true; image.size = NSSize(width: 18, height: 18); statusItem.button?.image = image }
        statusItem.button?.toolTip = "AI Usage Monitor"
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
    func button(_ title: String, _ action: Selector, role: CommandRole = .neutral) -> NSButton {
        let result = FlatButton(title: CqsLocale.t(title), target: self, action: action)
        result.role = role; result.isBordered = false; result.font = BoardType.command
        result.alignment = .center
        result.heightAnchor.constraint(equalToConstant: FlatButton.commandHeight).isActive = true
        return result
    }
    func checkInstallLocation() -> Bool {
        if CommandLine.arguments.contains("--ui-smoke") { return true }
        let path = Bundle.main.bundleURL.path
        let readOnlyVolume = path.hasPrefix("/Volumes/") && !FileManager.default.isWritableFile(atPath: Bundle.main.bundleURL.deletingLastPathComponent().path)
        guard readOnlyVolume || path.contains("/AppTranslocation/") else { return true }
        let prompt = NSAlert(); prompt.messageText = CqsLocale.t("Finish installing the app")
        prompt.informativeText = CqsLocale.t("1. Drag AI Usage Monitor.app from the disk image into Applications. Replace the old app if upgrading.\n2. Eject the disk image, then open AI Usage Monitor from Finder > Applications.\n3. Keep the app in the Dock for next time. You do not need to open the installer again.")
        prompt.addButton(withTitle: CqsLocale.t("Quit"))
        prompt.addButton(withTitle: CqsLocale.t("Open Applications"))
        NSApp.activate(ignoringOtherApps: true)
        if prompt.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications")) }
        return false
    }
    @objc func revealApplication() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    func smokeTest() {
        lifecycle("smokeTest entered")
        func precondition(_ condition: @autoclosure () -> Bool, _ message: String = "Smoke contract", file: StaticString = #file, line: UInt = #line) {
            if !condition() { fputs("UI smoke failed at \(file):\(line): \(message), page=\(page), document=\(pageDocument.bounds), viewport=\(pageScroll.contentView.bounds)\n", stderr); fflush(stderr); exit(1) }
        }
        do {
            let output = URL(fileURLWithPath: CommandLine.arguments.last!); try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            precondition(updateNotice.isHidden || updateNotice.superview == nil, "Update notice must be hidden by default")
            precondition(updateNotice.title.isEmpty, "Update notice has an unexpected title: \(updateNotice.title)")
            precondition(updateNotice.image != nil && updateNotice.imagePosition == .imageOnly, "Update notice is missing its image-only presentation")
            updateNotice.isHidden = false
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
                CqsLocale.language = language; languagePicker.selectItem(at: CqsLocale.modes.firstIndex(of: language) ?? 0)
                for action in [showAuthorizationHelp, showStatus, showDisplay, showSettings, showData, showHelp, showAbout] {
                    fputs("UI smoke: switching page, language \(language)\n", stderr)
                    action(); lifecycle("smoke page \(page) built; localization begin")
                    CqsLocale.apply(window.contentView!); lifecycle("smoke page \(page) layout begin")
                    window.contentView!.layoutSubtreeIfNeeded(); lifecycle("smoke page \(page) display begin")
                    window.displayIfNeeded()
                    assertV3Geometry()
                    precondition(updateNotice.title.isEmpty && !updateNotice.isHiddenOrHasHiddenAncestor && updateNotice.bounds.width == 36, "Update icon clipped after localization")
                    fputs("UI smoke: laid out \(page)\n", stderr)
                    precondition(abs(body.frame.minY - body.superview!.bounds.minY) < 2, "Page content is not top aligned")
                    if page == "subscription" { plan.selectItem(at: 2); enabled.state = .on; updateFields(); save(); precondition(!dirty && page == "subscription" && saveButton?.isEnabled == false) }
                    if page == "display" {
                        if displayChecks.contains(where: { $0.1.state == .off }) { toggleDisplayGroup() }
                        toggleDisplayGroup()
                        precondition(!dirty && bulkButton?.title == CqsLocale.t("Select all"))
                        let empty = read("display.json")
                        precondition(displayChecks.allSatisfy { empty[$0.0] as? Bool == false })
                        displayChecks[0].1.state = .on; selectionChanged(); toggleDisplayGroup()
                        let full = read("display.json")
                        precondition(!dirty && bulkButton?.title == CqsLocale.t("Select none"))
                        precondition(displayChecks.allSatisfy { full[$0.0] as? Bool == true })
                    }
                    let view = window.contentView!
                    func findTitle(_ parent: NSView) -> NSView? { if parent.identifier?.rawValue == "brand-title" { return parent }; for child in parent.subviews { if let match = findTitle(child) { return match } }; return nil }
                    guard let brand = findTitle(view) as? NSTextField, !brand.isHiddenOrHasHiddenAncestor, brand.bounds.width >= brand.intrinsicContentSize.width - 1, brand.bounds.height > 10 else { throw NSError(domain: "CQS", code: 4, userInfo: [NSLocalizedDescriptionKey: "Brand header is hidden or clipped"]) }
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(page + "-" + language + ".png"))
                    for size in [NSSize(width: 820, height: 520), NSSize(width: 1024, height: 700), NSSize(width: 1440, height: 1000)] {
                        window.setContentSize(size); adaptLayout(); window.displayIfNeeded(); assertV3Geometry()
                        if let last = body.arrangedSubviews.last {
                            let target = last.convert(last.bounds, to: pageDocument)
                            pageDocument.scrollToVisible(target)
                            precondition(pageScroll.contentView.documentVisibleRect.intersects(target), "Last page action must be reachable below the header")
                            pageScroll.contentView.scroll(to: .zero)
                        }
                        if size.width == 1440 && window.contentView!.bounds.height >= 999 {
                            precondition(pageDocument.bounds.height <= pageScroll.contentView.bounds.height + 1, "Tall windows must not need vertical scrolling")
                        }
                        let resized = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                        view.cacheDisplay(in: view.bounds, to: resized)
                        try resized.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(page + "-" + language + "-\(Int(size.width))x\(Int(size.height)).png"))
                    }
                    window.setContentSize(initialSize); adaptLayout()
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
                precondition(overviewValues.count == MetricPresentation.keys.count && overviewTracks.count == 6)
                precondition(overviewValues["weekly"]!.convert(overviewValues["weekly"]!.bounds, to: window.contentView).minY > overviewValues["lifetime"]!.convert(overviewValues["lifetime"]!.bounds, to: window.contentView).minY)
                let plot = monthTrend!
                plot.update("2026-11", [0, 0, 500000], missing: [1]); plot.choose(0)
                precondition(plot.reading.contains("0 Token"))
                plot.choose(1); precondition(plot.reading.contains(CqsLocale.t("No usage records")))
                plot.cumulative = true; plot.choose(2)
                precondition(plot.reading.contains("500K Token"))
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
                let tokenChoices = ["daily", "average", "weekly", "monthly", "lifetime"]
                for (name, choices) in [("all-twelve", [:]), ("none", Dictionary(uniqueKeysWithValues: MetricPresentation.keys.map { ($0, false) })), ("tokens-only", Dictionary(uniqueKeysWithValues: MetricPresentation.keys.map { ($0, tokenChoices.contains($0)) }))] as [(String, [String: Bool])] {
                    try write("display.json", choices); page = ""; showStatus(); updateMetrics(true)
                    window.contentView!.layoutSubtreeIfNeeded()
                    assertV3Geometry()
                    precondition(overviewValues.count == (name == "none" ? 0 : name == "tokens-only" ? tokenChoices.count : MetricPresentation.keys.count))
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
        func require(_ condition: @autoclosure () -> Bool, _ message: String = "Window resize contract failed") {
            if !condition() {
                if let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments.last!).appendingPathComponent("geometry-failure.png"))
                }
                fputs("UI geometry failed (\(page)): \(message)\n", stderr); fflush(stderr); exit(1)
            }
        }
        func find(_ id: String, in view: NSView) -> NSView? {
            if view.identifier?.rawValue == id { return view }
            for child in view.subviews { if let found = find(id, in: child) { return found } }
            return nil
        }
        let content = window.contentView!
        require(window.styleMask.contains(.resizable) && window.contentMinSize.width == 820)
        let titleRect = toolbarTitle.superview!.convert(toolbarTitle.alignmentRect(forFrame: toolbarTitle.frame), to: content)
        require(abs(titleRect.minX - body.convert(body.bounds, to: content).minX) <= 1, "Title and body must share the leading edge")
        if page == "data" { require(languagePicker.isBordered && languagePicker.bounds.width >= languagePicker.intrinsicContentSize.width - 1 && languagePicker.bounds.width < 220, "Language popup must fit its native label and menu indicator") }
        guard let commands = find("window-commands", in: content) as? NSStackView else { require(false, "Missing window commands"); return }
        let actions = commands.arrangedSubviews.compactMap { $0 as? FlatButton }
        require(actions.map { $0.role } == [.quiet, .secondary, .primary], "Footer must use one button family in command order")
        require(actions.allSatisfy { $0.font == BoardType.command && abs($0.bounds.height - FlatButton.commandHeight) < 1 }, "Footer controls must share type and height")
        if page == "about" {
            guard let logo = find("about-logo", in: content) as? NSButton else { require(false, "Missing project logo"); return }
            require(logo.image != nil && logo.imagePosition == .imageOnly && logo.title.isEmpty && logo.alternateTitle.isEmpty, "Localized logo must remain image only")
        }
        if page == "subscription", let identity = planSourceField.superview as? NSStackView {
            require(identity.arrangedSubviews.count == 3 && identity.spacing == 4 && planSourceField.font == BoardType.note, "Keep plan notes in one text group")
        }
        if page == "overview", let source = find("source-status", in: body), !runtimeIssue && stage != "failed" {
            require(body.customSpacing(after: source) == 4, "Group source and feedback")
        }
        let commandRect = commands.convert(commands.bounds, to: content)
        let viewportRect = pageScroll.convert(pageScroll.bounds, to: content)
        require(content.bounds.contains(commandRect) && commandRect.maxY <= viewportRect.minY + 1 &&
            abs(commandRect.maxX - viewportRect.maxX) < 2, "Window commands must stay below the page and align with its trailing edge")
        if let rowCount = ["data": 5, "help": 5, "authorization": 4, "about": 3][page] {
            let edges = body.arrangedSubviews.compactMap { child -> CGFloat? in
                guard child.identifier?.rawValue == "preference-row", let row = child as? NSStackView, let control = row.arrangedSubviews.last else { return nil }
                return control.superview!.convert(control.alignmentRect(forFrame: control.frame), to: body).maxX
            }
            require(edges.count == rowCount && edges.max()! - edges.min()! < 2, "Page actions must share the trailing edge")
        }
        require(abs(pageDocument.bounds.width - pageScroll.contentView.bounds.width) < 2, "No horizontal scrolling: document=\(pageDocument.bounds), viewport=\(pageScroll.contentView.bounds), body=\(body.frame)")
        require(pageDocument.bounds.height + 1 >= body.frame.maxY, "Document must include the entire page")
        func checkBounds(_ view: NSView) {
            guard !view.isHiddenOrHasHiddenAncestor else { return }
            if view is NSControl || view is OptionalDatePicker {
                // AppKit text fields extend their frame 2px past the alignment
                // rect; validate the visible layout rect, not that drawing inset.
                let rect = view.superview!.convert(view.alignmentRect(forFrame: view.frame), to: pageDocument)
                require(rect.minX >= -1 && rect.maxX <= pageDocument.bounds.width + 1, "Control outside page: \((view as? NSTextField)?.stringValue ?? view.description), rect=\(rect), document=\(pageDocument.bounds), body=\(body.frame)")
                require(rect.maxY <= pageDocument.bounds.height + 1, "Control clipped below document")
                if view is NSControl { return }
            }
            view.subviews.forEach { checkBounds($0) }
        }
        checkBounds(body)
        if page == "overview", let charts = find("overview-charts", in: content) as? NSStackView {
            require(abs(charts.bounds.width - body.bounds.width) < 1, "Charts must span the full content width")
            if let quotas = find("quota-column", in: charts), let tokens = find("token-column", in: charts) {
                let q = quotas.convert(quotas.bounds, to: charts), t = tokens.convert(tokens.bounds, to: charts)
                if charts.orientation == .horizontal {
                    require(abs(q.width + t.width + charts.spacing - charts.bounds.width) < 2, "Columns must fill available width")
                    require(abs(q.minX - t.maxX - charts.spacing) < 2, "Columns must not overlap")
                } else {
                    require(abs(q.width - charts.bounds.width) < 2 && abs(t.width - charts.bounds.width) < 2, "Narrow charts must use full-width rows")
                    require(q.maxY <= t.minY + 1 || t.maxY <= q.minY + 1, "Stacked charts must not overlap")
                }
                lifecycle("geometry quota=\(q.width), tokens=\(t.width), gutter=\(t.minX - q.maxX)")
            }
            func checkLabels(_ view: NSView) {
                if view.identifier?.rawValue == "plot-label", let field = view as? NSTextField {
                    let width = (field.stringValue as NSString).size(withAttributes: [.font: field.font!]).width
                    require(field.bounds.width >= ceil(width) + 2, "Localized plot label is clipped: \(field.stringValue)")
                }
                view.subviews.forEach { checkLabels($0) }
            }
            checkLabels(charts)
        }
        if page == "subscription" {
            let planColumn = plan.superview!.convert(plan.alignmentRect(forFrame: plan.frame), to: body)
            require(planColumn.width > 200 && planColumn.minX >= -1 && planColumn.maxX <= body.bounds.width + 1, "Plan popup must fit available width: column=\(planColumn), body=\(body.bounds)")
            for control in [plan, tier, mode] { require(control.isBordered && control.bounds.height >= control.intrinsicContentSize.height - 1, "Native popup must not be clipped") }
            for control in [purchase, next] { require(abs(control.bounds.height - 36) < 1 && control.bounds.width >= 260, "Native date pickers must fit adaptive form tracks") }
            if body.bounds.width >= 640 {
                func rect(_ view: NSView) -> NSRect { view.convert(view.bounds, to: body) }
                require(abs(rect(plan).midY - rect(tier).midY) < 2, "Plan and tier must share a row")
                require(abs(rect(purchase).midY - rect(mode).midY) < 2, "Purchase date and date type must share a row")
                require(rect(plan).maxX < rect(tier).minX && rect(next).maxX < rect(enabled).minX, "Form columns must not overlap")
            }
            require(plan.font?.pointSize == purchase.picker.font?.pointSize && mode.font?.pointSize == next.picker.font?.pointSize, "Field typography must match")
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
            require(whitePixels > 4, "Open Codex symbol must render white on the blue button")
        }
    }
    func clear() {
        stopConnectionAnimation(); responsiveLayouts.removeAll(); restartButton = nil
        for view in body.arrangedSubviews { body.removeArrangedSubview(view); view.removeFromSuperview() }
        pageScroll.contentView.scroll(to: .zero)
    }
    func responsive(_ stack: NSStackView, threshold: CGFloat, ratio: CGFloat? = nil, wideAlignment: NSLayoutConstraint.Attribute = .top) {
        var constraints: [NSLayoutConstraint] = []
        var previous: Bool?
        let layout: (CGFloat) -> Void = { width in
            let narrow = width < threshold
            guard previous != narrow else { return }; previous = narrow
            NSLayoutConstraint.deactivate(constraints); constraints = []
            stack.orientation = narrow ? .vertical : .horizontal
            stack.alignment = narrow ? .leading : wideAlignment
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
        window.contentView?.layoutSubtreeIfNeeded()
        // NSScrollView owns its clip frame. Size the document after tiling, then
        // measure wrapped content at that exact width rather than a stale frame.
        for _ in 0..<2 {
            pageScroll.tile()
            let viewport = pageScroll.contentView.bounds.size
            pageDocument.setFrameSize(NSSize(width: viewport.width, height: max(viewport.height, pageDocument.frame.height)))
            responsiveLayouts.forEach { $0(viewport.width) }
            pageDocument.layoutSubtreeIfNeeded()
            pageDocument.setFrameSize(NSSize(width: viewport.width, height: max(viewport.height, body.fittingSize.height)))
            pageDocument.layoutSubtreeIfNeeded()
        }
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
        guard resolvePendingEdits() else { languagePicker.selectItem(at: CqsLocale.modes.firstIndex(of: CqsLocale.mode) ?? 0); return }
        let mode = CqsLocale.modes[languagePicker.indexOfSelectedItem]; CqsLocale.language = CqsLocale.resolve(mode)
        UserDefaults.standard.set(mode, forKey: "cqs-language")
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
        key.font = BoardType.body
        if let field = value as? NSTextField { field.font = BoardType.body }
        key.widthAnchor.constraint(equalToConstant: 130).isActive = true; row.addArrangedSubview(key); row.addArrangedSubview(value); (target ?? body).addArrangedSubview(row)
        if value is NSPopUpButton { value.widthAnchor.constraint(equalToConstant: 340).isActive = true }
    }
    @objc func showStatus() {
        lifecycle("overview enter (page=\(page), stage=\(stage))")
        if page == "overview" { tick(); present(); return }
        guard beginPage("overview") else { return }; showingSettings = false; rows = []
        lifecycle("overview hierarchy cleared; header begin")
        heading("Usage overview")
        detail.font = BoardType.note; detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 0
        if runtimeIssue || stage == "failed" { body.addArrangedSubview(detail) }
        if runtimeIssue { authorizationButtons() }
        if errorText.trimmingCharacters(in: .whitespacesAndNewlines) == "E_RESTART_REQUIRED" {
            restartButton = button("Save work, restart and connect", #selector(confirmRestart), role: .secondary)
            body.addArrangedSubview(restartButton!)
        }
        body.spacing = stage.hasPrefix("mounted") && !runtimeIssue && errorText.isEmpty ? 16 : 10
        let statusLines = NSStackView(); statusLines.orientation = .horizontal; statusLines.alignment = .top; statusLines.distribution = .fillEqually; statusLines.spacing = 16
        for title in ["Client","Quota data","Token data","Last sync"] {
            let cell = NSStackView(); cell.orientation = .vertical; cell.alignment = .leading; cell.spacing = 4
            let label = NSTextField(labelWithString: CqsLocale.t(title)); label.font = BoardType.caption; label.textColor = .secondaryLabelColor
            let field = NSTextField(labelWithString: "--"); field.font = BoardType.caption; field.lineBreakMode = .byTruncatingTail
            cell.addArrangedSubview(label); cell.addArrangedSubview(field); rows.append(field); statusLines.addArrangedSubview(cell)
        }
        overviewValues = [:]; overviewCaptions = [:]; overviewTracks = [:]; dailyLabel = nil; dailyNote = nil
        let display = read("display.json")
        overviewSignature = MetricPresentation.keys.map { display[$0] as? Bool == false ? "0" : "1" }.joined() + (stage.hasPrefix("mounted") ? "mounted" : "waiting")
        func has(_ key: String) -> Bool { display[key] as? Bool != false }
        let charts = NSStackView(); charts.orientation = .horizontal; charts.alignment = .top; charts.spacing = 38; charts.distribution = .fill; charts.identifier = NSUserInterfaceItemIdentifier("overview-charts")
        let quotas = column(spacing: 8), tokens = column(spacing: 10)
        charts.spacing = 22
        quotas.identifier = NSUserInterfaceItemIdentifier("quota-column")
        tokens.identifier = NSUserInterfaceItemIdentifier("token-column")
        quotas.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        quotas.wantsLayer = true
        fill(quotas, NSColor.labelColor.withAlphaComponent(0.045))
        quotas.layer?.cornerRadius = 7
        let utc = NSStackView()
        do {
            let stamp = label("", font: BoardType.note, muted: true)
            monthStamp = stamp
            let gap = NSView(); gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
            utc.addArrangedSubview(stamp); utc.addArrangedSubview(gap); utc.addArrangedSubview(label("UTC", font: BoardType.note, muted: true))
            body.addArrangedSubview(utc); utc.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        }
        let plot = MonthTrendView()
        plot.identifier = NSUserInterfaceItemIdentifier("monthly-trend")
        plot.setAccessibilityLabel(CqsLocale.t("Usage trend"))
        monthTrend = plot
        monthTrend?.cumulative = !has("daily") && has("monthly")
        if has("daily") || has("monthly") {
            let trendTitle = NSStackView(); trendTitle.alignment = .centerY; trendTitle.spacing = 5
            let chartHeading = label("Usage trend", font: BoardType.section)
            trendTitle.addArrangedSubview(chartHeading)
            let gap = NSView(); gap.setContentHuggingPriority(.defaultLow, for: .horizontal)
            trendTitle.addArrangedSubview(gap)
            let modes = NSSegmentedControl(labels: [CqsLocale.t("Daily"), CqsLocale.t("Cumulative")], trackingMode: .selectOne, target: self, action: #selector(changeTrend(_:)))
            modes.setEnabled(has("daily"), forSegment: 0); modes.setEnabled(has("monthly"), forSegment: 1)
            modes.segmentStyle = .rounded; modes.font = BoardType.command
            modes.selectedSegment = plot.cumulative ? 1 : 0
            trendTitle.addArrangedSubview(modes); tokens.addArrangedSubview(trendTitle)
            trendTitle.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true
            tokens.addArrangedSubview(plot); plot.heightAnchor.constraint(equalToConstant: 198).isActive = true
            plot.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true
            let reading = label("No usage records", font: BoardType.numberNote, muted: true)
            tokens.addArrangedSubview(reading)
            reading.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true
            plot.changed = { [weak plot, weak reading] in reading?.stringValue = plot?.reading ?? "" }
        }
        func row(_ key: String, _ name: String, emphasis: Bool = false) -> NSStackView {
            let row = NSStackView(); row.spacing = 8; row.alignment = .centerY; row.distribution = .fill
            let nameField = label(name, font: BoardType.note, muted: !emphasis)
            nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let value = label("--", font: emphasis ? BoardType.largeMetric : BoardType.metric); value.alignment = .right
            value.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addArrangedSubview(nameField)
            if ["weekly", "lifetime"].contains(key) {
                let track = QuotaTrack(); track.heightAnchor.constraint(equalToConstant: 5).isActive = true
                track.widthAnchor.constraint(equalToConstant: 46).isActive = true
                overviewTracks[key] = track; row.addArrangedSubview(track)
            }
            row.addArrangedSubview(value)
            overviewValues[key] = value; overviewCaptions[key] = label("Not returned", font: BoardType.caption, muted: true)
            return row
        }
        if has("daily") || has("average") {
            let pair = NSStackView(); pair.distribution = .fillEqually; pair.spacing = 13
            for (key,name) in [("daily","Daily tokens"),("average","Monthly daily average")] where has(key) {
                let cell = column(spacing: 5), reading = row(key,name)
                if key == "daily" { dailyLabel = reading.arrangedSubviews.first as? NSTextField }
                let track = QuotaTrack(); track.heightAnchor.constraint(equalToConstant: 5).isActive = true
                cell.addArrangedSubview(reading); cell.addArrangedSubview(track)
                reading.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
                track.widthAnchor.constraint(equalTo: cell.widthAnchor).isActive = true
                overviewTracks[key] = track; pair.addArrangedSubview(cell)
            }
            tokens.addArrangedSubview(pair); pair.widthAnchor.constraint(equalTo: tokens.widthAnchor).isActive = true
        }
        let resetKeys = [("reset","Quota reset date"),("resetCredits","Reset count"),("credits","Credits")]
        let tokenKeys = [("monthly","Monthly tokens"),("weekly","Weekly tokens"),("lifetime","Lifetime tokens")]
        let hasDials = has("short") || has("week")
        if hasDials || (resetKeys + tokenKeys).contains(where: { has($0.0) }) {
            quotas.addArrangedSubview(label(hasDials ? "Quota remaining" : "Quota and resets", font: BoardType.section))
            if hasDials {
                let dials = NSStackView(); dials.distribution = .fillEqually; dials.spacing = 8
                for (key,name) in [("short","5-hour remaining"),("week","Weekly remaining")] where has(key) {
                    let cell = column(spacing: 3)
                    let gauge = NSView(), track = QuotaTrack(); track.dial = true
                    let value = label("--", font: BoardType.gauge); value.alignment = .center
                    let caption = label("Not returned", font: BoardType.caption, muted: true); caption.alignment = .center
                    let heading = label(name, font: BoardType.caption); heading.alignment = .center
                    track.translatesAutoresizingMaskIntoConstraints = false; value.translatesAutoresizingMaskIntoConstraints = false
                    gauge.addSubview(track); gauge.addSubview(value)
                    NSLayoutConstraint.activate([gauge.heightAnchor.constraint(equalToConstant: 59),track.leadingAnchor.constraint(equalTo:gauge.leadingAnchor),track.trailingAnchor.constraint(equalTo:gauge.trailingAnchor),track.topAnchor.constraint(equalTo:gauge.topAnchor),track.bottomAnchor.constraint(equalTo:gauge.bottomAnchor),value.centerXAnchor.constraint(equalTo:gauge.centerXAnchor),value.bottomAnchor.constraint(equalTo:gauge.bottomAnchor, constant:-6)])
                    for item in [gauge,heading,caption] {cell.addArrangedSubview(item);item.widthAnchor.constraint(equalTo:cell.widthAnchor).isActive = true}
                    overviewValues[key] = value; overviewCaptions[key] = caption; overviewTracks[key] = track
                    dials.addArrangedSubview(cell)
                }
                quotas.addArrangedSubview(dials); dials.widthAnchor.constraint(equalTo: quotas.widthAnchor,constant:-24).isActive = true
            }
            for (key,name) in tokenKeys where has(key) {
                let field = row(key,name,emphasis:key=="monthly")
                quotas.addArrangedSubview(field);field.widthAnchor.constraint(equalTo:quotas.widthAnchor,constant:-24).isActive = true
            }
            if resetKeys.contains(where: { has($0.0) }) { let line = separator();quotas.addArrangedSubview(line);line.widthAnchor.constraint(equalTo:quotas.widthAnchor,constant:-24).isActive = true }
            for (key,name) in resetKeys where has(key) {
                let field = row(key,name);quotas.addArrangedSubview(field);field.widthAnchor.constraint(equalTo:quotas.widthAnchor,constant:-24).isActive = true
            }
        }
        if !tokens.arrangedSubviews.isEmpty { charts.addArrangedSubview(tokens) }
        if !quotas.arrangedSubviews.isEmpty { charts.addArrangedSubview(quotas) }
        if !charts.arrangedSubviews.isEmpty {
            body.addArrangedSubview(charts); charts.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
            responsive(charts, threshold: 700, ratio: 0.64)
        }
        let meta = NSStackView(); meta.spacing = 26
        for (key, name) in [("plan", "Plan"), ("renewal", "Renewal date")] where has(key) {
            let row = NSStackView(); row.spacing = 8; row.addArrangedSubview(label(name, font: BoardType.note, muted: true)); let value = label("--", font: BoardType.note, muted: true); row.addArrangedSubview(value); overviewValues[key] = value; meta.addArrangedSubview(row)
        }
        if !meta.arrangedSubviews.isEmpty { let line = separator(); body.addArrangedSubview(line); line.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true; body.addArrangedSubview(meta) }
        if overviewValues.isEmpty { paragraph("No metrics selected."); body.addArrangedSubview(button("Display choices", #selector(showDisplay))) }
        let source = NSTextField(wrappingLabelWithString: CqsLocale.t("Usage: local CLI. Plan: desktop detection or manual record."))
        source.font = BoardType.note; source.textColor = .secondaryLabelColor
        source.identifier = NSUserInterfaceItemIdentifier("source-status"); appendReadingColumn(source)
        if detail.superview == nil {
            body.addArrangedSubview(detail)
            body.setCustomSpacing(4, after: source)
        }
        // Cross-view constraints require a common ancestor before activation.
        precondition(detail.isDescendant(of: body), "Overview detail must be attached before width activation")
        detail.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        lifecycle("overview detail attached; width constraint activated")
        metricFields = ["short", "week", "daily", "weekly", "lifetime", "average"].map { overviewValues[$0] ?? label("--", font: BoardType.section) }
        metricCaptions = ["short", "week", "daily", "weekly", "lifetime", "average"].map { overviewCaptions[$0] ?? label("Not returned", font: BoardType.caption) }
        // The fixed status fields remain available as accessibility/tooltips, without another visual block.
        headline.toolTip = rows.map { $0.stringValue }.joined(separator: " / ")
        lifecycle("overview hierarchy complete; tick begin")
        tick(); lifecycle("overview tick returned; present begin")
        present(); lifecycle("overview present returned")
    }
    func label(_ text: String, font: NSFont, muted: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: CqsLocale.t(text)); field.font = font; field.textColor = muted ? .secondaryLabelColor : .labelColor; return field
    }
    func column(spacing: CGFloat) -> NSStackView { let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.distribution = .fill; stack.spacing = spacing; return stack }
    func separator() -> NSView { let view = NSBox(); view.boxType = .separator; view.heightAnchor.constraint(equalToConstant: 1).isActive = true; return view }
    func axisRow(_ values: [String]) -> NSStackView {
        let row = NSStackView(); row.distribution = .fillEqually
        for (index, value) in values.enumerated() { let field = label(value, font: BoardType.caption, muted: true); field.alignment = index == 0 ? .left : index == 1 ? .center : .right; row.addArrangedSubview(field) }; return row
    }
    @objc func showSettings() {
        guard beginPage("subscription") else { return }; showingSettings = true; let member = read("membership.json")
        familyEdited = false; planSource = member["planSource"] as? String ?? "manual"
        heading("Plan and dates")
        enabled.state = member["enabled"] as? Bool == true ? .on : .off; enabled.target = self; enabled.action = #selector(updateFields)
        plan.removeAllItems(); plan.addItems(withTitles: ["Free", "Go", "Plus", "Pro", "Business", "Enterprise", "Edu", CqsLocale.t("Other / unknown")])
        let index = ["free", "go", "plus", "pro", "business", "enterprise", "edu", "other"].firstIndex(of: member["plan"] as? String ?? "other") ?? 7
        plan.selectItem(at: index); plan.target = self; plan.action = #selector(planChanged)
        for field in [purchase, next] { field.onChange = { [weak self] in self?.updateFields() } }
        purchase.stringValue = member["purchaseDate"] as? String ?? ""; next.stringValue = member["date"] as? String ?? ""
        loadTiers(member["tier"] as? String ?? "unknown")
        tier.target = self; tier.action = #selector(tierChanged)
        mode.removeAllItems(); mode.addItems(withTitles: [CqsLocale.t("Monthly estimate"), CqsLocale.t("Set renewal date"), CqsLocale.t("Set expiry date")]); mode.selectItem(at: member["monthlyEstimate"] as? Bool == true ? 0 : member["kind"] as? String == "expiry" ? 2 : 1); mode.target = self; mode.action = #selector(updateFields)
        mode.addItem(withTitle: CqsLocale.t("Business annual estimate")); if member["annualEstimate"] as? Bool == true { mode.selectItem(at: 3) }
        let form = column(spacing: 12)
        appendReadingColumn(form)
        func full(_ view: NSView) {
            form.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
        }
        func pair(_ left: NSView, _ right: NSView, wideAlignment: NSLayoutConstraint.Attribute = .top) {
            let row = NSStackView(views: [left, right]); row.spacing = 18
            full(row); responsive(row, threshold: 640, wideAlignment: wideAlignment)
        }
        let summary = NSStackView(); summary.spacing = 12; summary.alignment = .centerY; summary.distribution = .fill
        planSummary.font = BoardType.section
        planSummary.lineBreakMode = .byTruncatingTail
        let identity = column(spacing: 4)
        identity.addArrangedSubview(planSummary); identity.addArrangedSubview(planSourceField)
        identity.setCustomSpacing(6, after: planSummary)
        planSourceField.widthAnchor.constraint(equalTo: identity.widthAnchor).isActive = true
        summary.addArrangedSubview(identity)
        let detect = button("Detect plan", #selector(detectPlan), role: .secondary); detectPlanButton = detect; detect.isEnabled = planProcess == nil
        detect.setContentHuggingPriority(.required, for: .horizontal)
        planSourceField.font = BoardType.note; planSourceField.textColor = .secondaryLabelColor
        planSourceField.usesSingleLineMode = false; planSourceField.lineBreakMode = .byWordWrapping; planSourceField.cell?.wraps = true
        planSourceField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        planSourceField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        identity.setContentHuggingPriority(.defaultLow, for: .horizontal)
        summary.addArrangedSubview(detect); full(summary)
        let note = NSTextField(wrappingLabelWithString: CqsLocale.t("Only record your existing Codex subscription. No sign-up or purchase for this tool."))
        note.font = BoardType.note; note.textColor = .secondaryLabelColor
        identity.addArrangedSubview(note); note.widthAnchor.constraint(equalTo: identity.widthAnchor).isActive = true
        full(separator())
        pair(formField("Plan badge", plan), formField("Specific tier (manual, optional)", tier))
        full(separator()); form.addArrangedSubview(label("Dates and renewal", font: BoardType.section))
        pair(formField("Purchase date", purchase), formField("Date type", mode))
        enabled.font = BoardType.body
        let visibility = NSStackView(views: [enabled]); visibility.alignment = .centerY
        visibility.heightAnchor.constraint(equalToConstant: 36).isActive = true
        pair(formField("Renewal / expiry", next), visibility, wideAlignment: .bottom)
        updateFields()
        paragraph("Dates are optional. Detection never changes dates. Leave blank to hide.")
        let commands = NSStackView(); commands.spacing = 8
        saveButton = button("Save", #selector(save), role: .secondary); commands.addArrangedSubview(saveButton!); body.addArrangedSubview(commands); editingReady = true; present()
    }
    @objc func updateFields() {
        markDirty()
        let estimated = mode.indexOfSelectedItem == 0 || mode.indexOfSelectedItem == 3
        if estimated {
            next.stringValue = MetricPresentation.renewal(["enabled": true, "purchaseDate": purchase.stringValue, "monthlyEstimate": mode.indexOfSelectedItem == 0, "annualEstimate": mode.indexOfSelectedItem == 3]) ?? ""
        }
        next.isEnabled = !estimated
        let family = plan.titleOfSelectedItem ?? ""
        if tier.isEnabled, tier.indexOfSelectedItem > 0, let option = tier.titleOfSelectedItem {
            planSummary.stringValue = option.hasPrefix(family + " ") ? option : family + " / " + option
        } else { planSummary.stringValue = family }
        planSourceField.stringValue = planProcess != nil ? CqsLocale.t("Detecting plan. The official Codex usage panel may open briefly.") : planFailure.isEmpty ? CqsLocale.t(planSource == "desktop" ? "Desktop detection" : "Manual record (locked)") : planFailureMessage()
    }
    func formField(_ title: String, _ control: NSView) -> NSStackView {
        let field = column(spacing: 5), slot = NSView()
        field.addArrangedSubview(label(title, font: BoardType.body)); field.addArrangedSubview(slot)
        slot.addSubview(control); control.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([slot.widthAnchor.constraint(equalTo: field.widthAnchor), slot.heightAnchor.constraint(equalToConstant: 36),
            control.leadingAnchor.constraint(equalTo: slot.leadingAnchor), control.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: slot.centerYAnchor)])
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if let popup = control as? NSPopUpButton { popup.font = BoardType.body; popup.bezelStyle = .rounded; popup.setAccessibilityLabel(CqsLocale.t(title)) }
        return field
    }
    private let planFamilies = ["free", "go", "plus", "pro", "business", "enterprise", "edu", "other"]
    private func loadTiers(_ selected: String) {
        let family = planFamilies.indices.contains(plan.indexOfSelectedItem) ? planFamilies[plan.indexOfSelectedItem] : "other"
        let options = MetricPresentation.tiers(for: family)
        tier.removeAllItems()
        tier.addItems(withTitles: options.map { key in
            key == "unknown" ? CqsLocale.t("Other / unknown") : family == "pro" ? "Pro " + key : key.capitalized
        })
        tier.selectItem(at: options.firstIndex(of: selected) ?? 0)
        tier.isEnabled = options.count > 1
    }
    @objc func planChanged() { familyEdited = true; planSource = "manual"; loadTiers("unknown"); updateFields() }
    @objc func tierChanged() { updateFields() }
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
        toolbar.addArrangedSubview(selectionMeter)
        let toolbarGap = NSView(); toolbarGap.setContentHuggingPriority(.defaultLow, for: .horizontal); toolbarGap.setContentCompressionResistancePriority(.defaultLow, for: .horizontal); toolbar.addArrangedSubview(toolbarGap)
        body.addArrangedSubview(toolbar)
        selectionCount.font = BoardType.metric
        toolbar.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true; body.setCustomSpacing(18, after: toolbar)
        let groups: [(String, [(String, String)])] = [("Plan and dates", [("plan", "Plan badge"), ("renewal", "Renewal date")]), ("Quota and resets", [("short", "5-hour remaining"), ("week", "Weekly remaining"), ("reset", "Quota reset date"), ("resetCredits", "Reset count"), ("credits", "Credits")]), ("Token usage", [("daily", "Daily tokens"), ("average", "Monthly daily average"), ("weekly", "Weekly tokens"), ("monthly", "Monthly tokens"), ("lifetime", "Lifetime tokens")])]
        for (name, items) in groups {
            let group = column(spacing: 0); let groupTitle = label(name, font: BoardType.section)
            group.addArrangedSubview(groupTitle); group.setCustomSpacing(8, after: groupTitle); stack.addArrangedSubview(group)
            for (key, title) in items {
                let check = NSButton(checkboxWithTitle: CqsLocale.t(title), target: self, action: #selector(selectionChanged)); check.font = BoardType.body
                check.heightAnchor.constraint(equalToConstant: 29).isActive = true
                check.state = values[key] as? Bool == false ? .off : .on; displayChecks.append((key, check)); group.addArrangedSubview(check)
            }
        }
        appendReadingColumn(stack)
        responsive(stack, threshold: 700)
        let bulk = button("Select none", #selector(toggleDisplayGroup), role: .secondary); bulkButton = bulk
        body.addArrangedSubview(bulk); updateSelectionCount()
        paragraph("Changes are saved automatically and applied to the overview and sidebar.")
        editingReady = true; present()
    }
    @objc func saveDisplay() {
        do { var value = try readForSave("display.json"); for (key, check) in displayChecks { value[key] = check.state == .on }; try write("display.json", value); saved() }
        catch { alert(error.localizedDescription) }
    }
    func updateSelectionCount() {
        let count = displayChecks.filter { $0.1.state == .on }.count
        selectionMeter.maxValue = Double(displayChecks.count); selectionMeter.doubleValue = Double(count)
        selectionMeter.setAccessibilityLabel(CqsLocale.t("Display choices"))
        selectionCount.stringValue = CqsLocale.t("Selected") + " \(count) / \(displayChecks.count)"
        bulkButton?.title = CqsLocale.t(count == displayChecks.count ? "Select none" : "Select all")
    }
    @objc func selectionChanged() { markDirty(); updateSelectionCount(); if dirty { saveDisplay() } }
    @objc func toggleDisplayGroup() {
        let target: NSControl.StateValue = displayChecks.allSatisfy { $0.1.state == .on } ? .off : .on
        displayChecks.forEach { $0.1.state = target }; selectionChanged()
    }
    func paragraph(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: CqsLocale.t(text)); label.font = BoardType.body
        body.addArrangedSubview(label); label.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
    }
    func heading(_ text: String) {
        toolbarTitle.stringValue = CqsLocale.t(text)
    }
    private func appendReadingColumn(_ view: NSView) {
        body.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
    }
    private func sectionRule(_ title: String) {
        let field = label(title, font: BoardType.section)
        let rule = separator(), row = NSStackView(views: [field, rule])
        row.alignment = .centerY; row.spacing = 12; row.distribution = .fill
        field.setContentHuggingPriority(.required, for: .horizontal); appendReadingColumn(row)
    }
    private func setting(_ title: String, _ control: NSView, detail: String? = nil) {
        let label = NSTextField(wrappingLabelWithString: CqsLocale.t(title))
        label.font = detail == nil ? BoardType.body : BoardType.command
        let copy = NSStackView(views: [label]); copy.orientation = .vertical; copy.alignment = .leading; copy.spacing = 4
        if let detail = detail {
            let note = NSTextField(wrappingLabelWithString: CqsLocale.t(detail))
            note.font = BoardType.note; note.textColor = .secondaryLabelColor
            copy.addArrangedSubview(note); note.widthAnchor.constraint(equalTo: copy.widthAnchor).isActive = true
        }
        copy.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        let row = NSStackView(views: [copy, control]); row.alignment = .centerY; row.spacing = 20; row.distribution = .fill
        row.identifier = NSUserInterfaceItemIdentifier("preference-row")
        copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.widthAnchor.constraint(equalTo: copy.widthAnchor).isActive = true
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.edgeInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        appendReadingColumn(row)
    }
    @objc func showHelp() {
        guard beginPage("help") else { return }; showingSettings = true; heading("Diagnostics")
        if let issue = updateRecoveryMessage() { paragraph(issue) }
        sectionRule("Connection status")
        setting("Connection status", button("Reconnect", #selector(reconnect), role: .secondary), detail: "Check that Codex can chat. If the sidebar is hidden, enlarge the window before reconnecting.")
        setting("Permissions", button("Open Privacy & Security", #selector(openSecuritySettings)))
        setting("Installation and approval guide", button("Installation and approval guide", #selector(openInstallGuide)))
        sectionRule("Diagnostic report")
        setting("Export sanitized diagnostics", button("Export sanitized diagnostics", #selector(exportDiagnostics)), detail: "Includes version, system, connection state and error codes; excludes keys, chats, accounts and paths.")
        setting("Issue feedback", button("Submit feedback on GitHub", #selector(openIssues)), detail: "Review the report and hide personal details in screenshots before attaching them to an issue.")
        paragraph("If Codex is already running, reconnect first. When a restart is required, save work and approve it in Usage overview. You can cancel or quit Codex manually instead.")
        paragraph("No automatic uploads. You choose what to submit. A GitHub account is required to post an issue."); present()
    }
    func applyAppearance() {
        let mode = UserDefaults.standard.integer(forKey: "board-appearance")
        NSApp.appearance = mode == 1 ? NSAppearance(named: .aqua) : mode == 2 ? NSAppearance(named: .darkAqua) : nil
    }
    @objc func changeAppearance(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "board-appearance"); applyAppearance()
    }
    @objc func showData() {
        guard beginPage("data") else { return }; showingSettings = true; heading("Data and settings")
        let picker = NSPopUpButton(frame: .zero, pullsDown: false); picker.font = BoardType.body
        picker.addItems(withTitles: ["System", "Light", "Dark"].map(CqsLocale.t))
        picker.selectItem(at: UserDefaults.standard.integer(forKey: "board-appearance"))
        picker.target = self; picker.action = #selector(changeAppearance(_:)); picker.setAccessibilityLabel(CqsLocale.t("Appearance"))
        for (action, detail, selector) in [
            ("Backup settings", "Export display choices, language and your manually recorded subscription.", #selector(backupSettings)),
            ("Restore settings", "Select a backup and confirm before replacing your current settings.", #selector(restoreSettings)),
            ("Clear observation history", "Clear local observation times only. Official usage and chats are not deleted.", #selector(clearHistory))
        ] {
            setting(action, button(action, selector), detail: detail)
        }
        let divider = separator(); body.addArrangedSubview(divider)
        if let lastRow = body.arrangedSubviews.dropLast().last { divider.widthAnchor.constraint(equalTo: lastRow.widthAnchor).isActive = true }
        languagePicker.item(at: 0)?.title = CqsLocale.t("System")
        languagePicker.selectItem(at: CqsLocale.modes.firstIndex(of: CqsLocale.mode) ?? 0)
        setting("Language", languagePicker); setting("Appearance", picker)
        let prefs = read("weekly-alert.json"), enabled = prefs["enabled"] as? Bool ?? false
        let toggle = NSSwitch(); toggle.state = enabled ? .on : .off
        toggle.target = self; toggle.action = #selector(changeWeeklyReminder(_:))
        toggle.setAccessibilityLabel(CqsLocale.t("Low weekly quota reminder"))
        setting("Low weekly quota reminder", toggle)
        let threshold = NSPopUpButton(frame: .zero, pullsDown: false)
        threshold.addItems(withTitles: stride(from: 5, through: 50, by: 5).map { "\($0)%" })
        threshold.selectItem(withTitle: "\(prefs["threshold"] as? Int ?? 20)%")
        threshold.isEnabled = enabled; threshold.target = self; threshold.action = #selector(changeWeeklyThreshold(_:))
        threshold.setAccessibilityLabel(CqsLocale.t("Reminder threshold"))
        weeklyThresholdControl = threshold; setting("Reminder threshold", threshold); present()
    }
    @objc func changeWeeklyThreshold(_ sender: NSPopUpButton) {
        var prefs = read("weekly-alert.json"); prefs["threshold"] = (sender.indexOfSelectedItem + 1) * 5
        do { try write("weekly-alert.json", prefs) } catch { alert(error.localizedDescription) }
    }
    @objc func changeWeeklyReminder(_ sender: NSSwitch) {
        let enable = sender.state == .on
        func commit(_ allowed: Bool) {
            let prefs = self.read("weekly-alert.json")
            do { try self.write("weekly-alert.json", ["enabled":allowed, "threshold":prefs["threshold"] as? Int ?? 20]) }
            catch { self.alert(error.localizedDescription) }
            let saved = self.read("weekly-alert.json")["enabled"] as? Bool ?? false
            sender.state = saved ? .on : .off; sender.isEnabled = true; self.weeklyThresholdControl?.isEnabled = saved
        }
        guard enable else { commit(false); return }
        sender.isEnabled = false
        UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]) { ok,_ in
            DispatchQueue.main.async { commit(ok); if !ok { self.alert(CqsLocale.t("Allow notifications in System Settings to enable reminders.")) } }
        }
    }
    func deliverWeeklyNotice() {
        let url = runtime.appendingPathComponent("weekly-notice.json")
        guard FileManager.default.fileExists(atPath:url.path) else { return }
        let n = read("weekly-notice.json")
        guard (try? FileManager.default.removeItem(at:url)) != nil else { return }
        let prefs = read("weekly-alert.json"), now = Date().timeIntervalSince1970
        guard prefs["enabled"] as? Bool == true, let threshold = prefs["threshold"] as? Int,
              let left = n["remaining"] as? Double, left >= 0, left <= Double(threshold),
              let reset = n["reset"] as? Double, reset > now,
              let stamp = n["observed"] as? Double, (0..<180).contains(now-stamp/1000) else { return }
        let message = UNMutableNotificationContent(); message.title = "AI Usage Monitor"
        message.body = CqsLocale.t("Weekly quota remaining") + ": " + NSNumber(value:left).stringValue + "%"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"weekly-\(Int(reset))",content:message,trigger:nil))
    }
    @objc func backupSettings() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "AI-Usage-Monitor-settings.json"
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
                languagePicker.selectItem(at: CqsLocale.modes.firstIndex(of: lang) ?? 0)
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
        let dialog = NSSavePanel(); dialog.nameFieldStringValue = "AI-Usage-Monitor-diagnostics.json"
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
    @objc func openIssues() { NSWorkspace.shared.open(URL(string: "https://github.com/kefen/AI-Usage-Monitor/issues/new")!) }
    @objc func showAbout() {
        guard beginPage("about") else { return }; showingSettings = true; heading("About project")
        let name = label("AI Usage Monitor", font: BoardType.title)
        let identity = column(spacing: 3); identity.addArrangedSubview(name); identity.addArrangedSubview(label("by KEFEN", font: BoardType.caption, muted: true))
        let logo = NSButton(image: NSApp.applicationIconImage, target: self, action: #selector(openGitHub))
        logo.title = ""; logo.alternateTitle = ""; logo.isBordered = false; logo.imageScaling = .scaleProportionallyDown; logo.imagePosition = .imageOnly
        logo.identifier = NSUserInterfaceItemIdentifier("about-logo")
        logo.toolTip = CqsLocale.t("Visit GitHub project"); logo.setAccessibilityLabel(logo.toolTip)
        NSLayoutConstraint.activate([logo.widthAnchor.constraint(equalToConstant: 52), logo.heightAnchor.constraint(equalToConstant: 52)])
        let masthead = NSStackView(views: [logo, identity]); masthead.spacing = 12; masthead.alignment = .centerY
        body.addArrangedSubview(masthead)
        paragraph("Local, read-only quota and Token indicators in the Codex sidebar. Choose the metrics you need; official controls always have priority.")
        paragraph("Unofficial software. Not affiliated with or endorsed by OpenAI.")
        paragraph("Author: KEFEN / License: MIT")
        appendReadingColumn(separator())
        setting("macOS " + (Bootstrap.releaseVersion ?? "--"), updateButton)
        body.addArrangedSubview(updateProgress); body.addArrangedSubview(updateProgressText)
        setting("GitHub", button("Visit GitHub project", #selector(openGitHub)))
        setting("Finder", button("Show application in Finder", #selector(revealApplication))); present()
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
        let family = planFamilies.indices.contains(plan.indexOfSelectedItem) ? planFamilies[plan.indexOfSelectedItem] : "other"
        if familyEdited { member["plan"] = family; member["planSource"] = "manual"; member["manualOverride"] = true }
        let options = MetricPresentation.tiers(for: family)
        let selectedTier = options.indices.contains(tier.indexOfSelectedItem) ? options[tier.indexOfSelectedItem] : "unknown"
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
        setting("Installation and approval guide", button("Installation and approval guide", #selector(openInstallGuide)), detail: "1. Verify the download source and checksum. You may stop and wait for a notarized version.")
        setting("Permissions", button("Open Privacy & Security", #selector(openSecuritySettings)), detail: "2. After a system warning, review the exact item in System Settings > Privacy & Security. If available, choose Open Anyway only if you trust it.")
        runtimeAction = button("Check runtime and connect", #selector(start), role: .secondary)
        setting("Connection status", runtimeAction!, detail: "3. Return here and check the runtime again. Do not disable system protections or grant unrelated permissions.")
        appendReadingColumn(separator())
        setting("Sidebar items", button("Display choices", #selector(showInstallChoices))); present()
    }
    @objc func showInstallChoices() {
        showDisplay()
        if page == "display" { body.addArrangedSubview(button("Back", #selector(showAuthorizationHelp))) }
    }
    func authorizationButtons() {
        let actions = NSStackView(); actions.spacing = 12
        actions.addArrangedSubview(button("Open Privacy & Security", #selector(openSecuritySettings)))
        actions.addArrangedSubview(button("Installation and approval guide", #selector(openInstallGuide)))
        body.addArrangedSubview(actions)
        responsive(actions, threshold: 700)
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
        deliverWeeklyNotice()
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
        headline.textColor = mounted ? .systemBlue : .labelColor
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
        let now = Date()
        let stamp = DateFormatter(); stamp.timeZone = TimeZone(secondsFromGMT: 0)
        stamp.locale = Locale(identifier: CqsLocale.language)
        stamp.setLocalizedDateFormatFromTemplate("yMMMM"); monthStamp?.stringValue = stamp.string(from: now)
        let key = String(ISO8601DateFormatter().string(from: now).prefix(7))
        let values = MetricPresentation.overview(snapshot, display: display, member: read("membership.json"), connected: connected, now: now.timeIntervalSince1970 * 1000)
        let history = snapshot["monthTrend"] as? [String: Any]
        let trend: (values: [Double?], missing: Set<Int>)
        let time = now.timeIntervalSince1970 * 1000
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        if connected, let generated = MetricPresentation.number(snapshot["generatedAt"]), time >= generated, time - generated < 90_000,
           let usage = MetricPresentation.number(snapshot["usageAt"]), time >= usage, time - usage < 5_400_000,
           history?["month"] as? String == key, let days = history?["days"] as? [Any] {
            trend = MetricPresentation.trendPoints(days, through: utc.component(.day, from: now))
        } else { trend = ([], []) }
        monthTrend?.update(key, trend.values, missing: trend.missing)
        let daily = snapshot["daily"] as? [String: Any] ?? [:]
        let maximum = MetricPresentation.plotMaximum([values["daily"]?.value != "--" ? MetricPresentation.number(daily["value"]) : nil, values["average"]?.value != "--" ? MetricPresentation.number(snapshot["monthAverage"]) : nil].compactMap { $0 })
        let tokenRange = max(1, [MetricPresentation.number(snapshot["week"]), MetricPresentation.number(snapshot["lifetime"])].compactMap { $0 }.max() ?? 0)
        for (key, value) in values {
            overviewValues[key]?.stringValue = CqsLocale.t(value.value)
            overviewValues[key]?.textColor = value.value == "--" ? .secondaryLabelColor : .labelColor
            overviewValues[key]?.toolTip = CqsLocale.t(value.caption)
            overviewValues[key]?.setAccessibilityLabel(CqsLocale.t(value.caption) + " " + value.value)
            overviewCaptions[key]?.stringValue = CqsLocale.t(value.caption)
            if ["short", "week"].contains(key) {
                overviewTracks[key]?.fraction = value.fraction
                if let fraction = value.fraction { overviewCaptions[key]?.stringValue = String(format: "%g%% ", (1 - fraction) * 100) + CqsLocale.t("Used") }
            } else if ["daily", "average"].contains(key) {
                let raw = key == "daily" ? daily["value"] : snapshot["monthAverage"]
                overviewTracks[key]?.fraction = value.value == "--" ? nil : MetricPresentation.number(raw).map { $0 / maximum }
            } else if ["weekly", "lifetime"].contains(key) {
                let raw = snapshot[key == "weekly" ? "week" : "lifetime"]
                overviewTracks[key]?.fraction = value.value == "--" ? nil : MetricPresentation.number(raw).map { $0 / tokenRange }
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
    @objc func changeTrend(_ sender: NSSegmentedControl) {
        guard let plot = monthTrend else { return }
        plot.cumulative = sender.selectedSegment == 1; plot.needsDisplay = true; plot.changed?()
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
    func showDownloadProgress(since: Double) {
        updateProgress.isHidden = false; updateProgressText.isHidden = false
        let state = read("updates/download-progress.json")
        guard let updated = state["updatedAt"] as? Double, updated >= since,
              let received = state["received"] as? Double, let total = state["total"] as? Double,
              total > 0, received >= 0, received <= total else {
            if !updateProgress.isIndeterminate { updateProgress.isIndeterminate = true }
            updateProgress.startAnimation(nil)
            updateProgressText.stringValue = CqsLocale.t("Connecting to update server...")
            return
        }
        let percent = Int(received / total * 100)
        updateProgress.stopAnimation(nil); updateProgress.isIndeterminate = false
        updateProgress.doubleValue = Double(percent)
        updateProgressText.stringValue = percent == 100 ? CqsLocale.t("Verifying update...") :
            ((state["attempt"] as? Int == 2 ? CqsLocale.t("Retrying download") : CqsLocale.t("Downloading update")) + " \(percent)%")
    }
    func endDownloadProgress() {
        updateProgressTimer?.invalidate(); updateProgressTimer = nil
        updateProgress.stopAnimation(nil); updateProgress.isHidden = true; updateProgressText.isHidden = true
    }
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
        if operation == "download" {
            showDownloadProgress(since: operationStarted)
            let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in self?.showDownloadProgress(since: operationStarted) }
            RunLoop.main.add(timer, forMode: .common); updateProgressTimer = timer
        }
        if operation == "prepare" {
            let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 96), styleMask: [.titled], backing: .buffered, defer: false)
            sheet.title = CqsLocale.t("Preparing update...")
            let spinner = NSProgressIndicator(frame: NSRect(x: 24, y: 28, width: 24, height: 24)); spinner.style = .spinning; spinner.startAnimation(nil); sheet.contentView?.addSubview(spinner)
            let message = label("Preparing update...", font: BoardType.body); message.frame = NSRect(x: 64, y: 30, width: 240, height: 20); sheet.contentView?.addSubview(message)
            updatePreparationSheet = sheet; window.beginSheet(sheet)
        }
        process.terminationHandler = { [weak self] child in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let self = self else { return }; self.updateProcess = nil; self.updateButton.isEnabled = true; self.updateNotice.isEnabled = true; self.updateButton.title = CqsLocale.t("Check for updates")
                self.endUpdatePreparation()
                self.endDownloadProgress()
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
        do { try process.run() } catch { endUpdatePreparation(); endDownloadProgress(); updateProcess = nil; updateButton.isEnabled = true; updateNotice.isEnabled = true; updateButton.title = CqsLocale.t("Check for updates"); if operation != "auto" { alert(updateFailureMessage("E_UPDATE_CONFIGURATION")) } }
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
        let a = NSAlert(); a.messageText = "AI Usage Monitor"; a.informativeText = text; a.runModal()
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
