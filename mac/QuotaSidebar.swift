import AppKit

// Native shell only. The shared Node core remains responsible for quota data.
final class QuotaApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexSidebarMeter")
    var runtime: URL { root.appendingPathComponent(".runtime") }
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var body = NSStackView()
    var headline = NSTextField(labelWithString: "正在连接")
    var detail = NSTextField(wrappingLabelWithString: "等待客户端与数据同步")
    var rows: [NSTextField] = []
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
    let enabled = NSButton(checkboxWithTitle: "显示会员日期", target: nil, action: nil)
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
        do { try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true) }
        catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 500), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Codex Quota Sidebar"; window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        let container = NSStackView(); container.orientation = .vertical; container.alignment = .leading; container.spacing = 20
        container.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        container.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(container)
        NSLayoutConstraint.activate([container.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor), container.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor), container.topAnchor.constraint(equalTo: window.contentView!.topAnchor), container.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)])
        let header = NSStackView(); header.spacing = 16
        let icon = NSImageView(image: NSImage(contentsOf: root.appendingPathComponent("assets/cqs-128.png")) ?? NSImage())
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true; icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let words = NSStackView(); words.orientation = .vertical; words.alignment = .leading; words.spacing = 4
        let title = NSTextField(labelWithString: "Codex Quota Sidebar"); title.font = .systemFont(ofSize: 21, weight: .regular)
        let version = NSTextField(labelWithString: "macOS 0.2.2-alpha.1 · CHUNG"); version.textColor = .secondaryLabelColor
        words.addArrangedSubview(title); words.addArrangedSubview(version); header.addArrangedSubview(icon); header.addArrangedSubview(words); container.addArrangedSubview(header)
        let divider = NSBox(); divider.boxType = .separator; container.addArrangedSubview(divider); divider.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        body.orientation = .vertical; body.alignment = .leading; body.spacing = 14; container.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48).isActive = true
        let spacer = NSView(); container.addArrangedSubview(spacer); spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(contentsOf: root.appendingPathComponent("assets/tray-template.png")) { image.isTemplate = true; image.size = NSSize(width: 18, height: 18); statusItem.button?.image = image }
        statusItem.button?.toolTip = "Codex Quota Sidebar"
        let menu = NSMenu()
        for (text, action) in [("查看状态", #selector(showStatus)), ("设置", #selector(showSettings)), ("侧栏内容", #selector(showDisplay)), ("刷新数据", #selector(refresh)), ("退出软件", #selector(stop))] {
            let item = NSMenuItem(title: text, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu; showStatus()
        if read("preferences.json")["cdpConsent"] as? Bool != true {
            let prompt = NSAlert(); prompt.messageText = "允许本机调试连接"; prompt.informativeText = "调试权限不只限于读取额度，同机其他程序可能访问该端口。退出软件不会关闭端口；需完整退出 Codex，再从官方入口重启。本工具非 OpenAI 官方产品，CLI 账号可能与桌面账号不同。"
            prompt.addButton(withTitle: "取消"); let agree = prompt.addButton(withTitle: "同意并继续"); agree.keyEquivalent = ""
            guard prompt.runModal() == .alertSecondButtonReturn else { NSApp.terminate(nil); return }
            do { var prefs = read("preferences.json"); prefs["cdpConsent"] = true; try write("preferences.json", prefs) }
            catch { alert(error.localizedDescription); NSApp.terminate(nil); return }
        }
        if read("preferences.json")["setupComplete"] as? Bool != true { showDisplay(); showSettings() } else { start() }
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.tick() }
    }
    func button(_ title: String, _ action: Selector, primary: Bool = false) -> NSButton {
        let result = NSButton(title: title, target: self, action: action); result.bezelStyle = .rounded; result.font = .systemFont(ofSize: 13, weight: .regular)
        if primary { result.bezelColor = green }
        result.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true; return result
    }
    func clear() { for view in body.arrangedSubviews { body.removeArrangedSubview(view); view.removeFromSuperview() } }
    func present() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    func line(_ label: String, _ value: NSView) {
        let row = NSStackView(); row.spacing = 20; let key = NSTextField(labelWithString: label); key.textColor = .secondaryLabelColor
        key.widthAnchor.constraint(equalToConstant: 130).isActive = true; row.addArrangedSubview(key); row.addArrangedSubview(value); body.addArrangedSubview(row)
    }
    @objc func showStatus() {
        showingSettings = false; clear(); rows = []
        headline.font = .systemFont(ofSize: 26, weight: .regular); body.addArrangedSubview(headline); body.addArrangedSubview(detail)
        detail.widthAnchor.constraint(lessThanOrEqualToConstant: 600).isActive = true
        for title in ["客户端", "额度数据", "Token 数据", "最近同步"] { let field = NSTextField(labelWithString: "--"); rows.append(field); line(title, field) }
        let commands = NSStackView(); commands.spacing = 8
        retry = button("重新连接", #selector(reconnect)); commands.addArrangedSubview(button("打开 Codex", #selector(openCodex))); commands.addArrangedSubview(retry); commands.addArrangedSubview(button("设置", #selector(showSettings))); commands.addArrangedSubview(button("退出软件", #selector(stop))); body.addArrangedSubview(commands)
        tick(); present()
    }
    @objc func showSettings() {
        showingSettings = true; clear(); let member = read("membership.json")
        enabled.state = member["enabled"] as? Bool == true ? .on : .off; enabled.target = self; enabled.action = #selector(updateFields); body.addArrangedSubview(enabled)
        plan.removeAllItems(); plan.addItems(withTitles: ["Plus","Pro / 未确定档位","Pro 100","Pro 200","Pro 500","Business / 未确定席位","Business Standard","Business Premium","Enterprise","Edu","Free","Go","其他 / 未确定"])
        let index = planIDs.indices.first { planIDs[$0] == (member["plan"] as? String) && (planTiers[$0] == (member["tier"] as? String ?? "unknown") || planTiers[$0].isEmpty) } ?? 12
        plan.selectItem(at: index); plan.target = self; plan.action = #selector(planChanged)
        for picker in [purchase, next] { picker.datePickerElements = [.yearMonthDay]; picker.datePickerStyle = .textFieldAndStepper; picker.target = self; picker.action = #selector(updateFields) }
        purchase.dateValue = date(member["purchaseDate"] as? String) ?? Date(); next.dateValue = date(member["date"] as? String) ?? Date()
        mode.removeAllItems(); mode.addItems(withTitles: ["月付推算", "指定续费日", "指定到期日"]); mode.selectItem(at: member["kind"] as? String == "expiry" ? 2 : member["date"] != nil ? 1 : 0); mode.target = self; mode.action = #selector(updateFields)
        mode.addItem(withTitle: "Business 年付推算"); if member["annualEstimate"] as? Bool == true { mode.selectItem(at: 3) }
        line("套餐", plan); line("购买日期", purchase); line("日期类型", mode); line("续费 / 到期日", next); updateFields()
        let commands = NSStackView(); commands.spacing = 8
        commands.addArrangedSubview(button("保存", #selector(save), primary: true)); commands.addArrangedSubview(button("跳过 / 隐藏", #selector(skip))); commands.addArrangedSubview(button("取消", #selector(showStatus))); body.addArrangedSubview(commands); present()
    }
    @objc func updateFields() {
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
        let keys = ["plan","short","week","reset","renewal","daily","average","weekly","lifetime"]
        let labels = ["套餐标识","5 小时剩余","本周剩余","额度重置日","会员续费日","每日 Token","日均 Token","本周 Token","累计 Token"]
        let values = read("display.json"), stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        var checks: [NSButton] = []
        for (key,label) in zip(keys,labels) { let check = NSButton(checkboxWithTitle: label, target: nil, action: nil); check.state = values[key] as? Bool == false ? .off : .on; checks.append(check); stack.addArrangedSubview(check) }
        stack.frame = NSRect(x: 0,y: 0,width: 300,height: 270)
        let dialog = NSAlert(); dialog.messageText = "侧栏显示内容"; dialog.accessoryView = stack; dialog.addButton(withTitle: "保存"); dialog.addButton(withTitle: "取消")
        if dialog.runModal() == .alertFirstButtonReturn { var result: [String: Any] = [:]; for (key,check) in zip(keys,checks) { result[key] = check.state == .on }; do { try write("display.json",result) } catch { alert(error.localizedDescription) } }
    }
    @objc func skip() { enabled.state = .off; save() }
    @objc func save() {
        if enabled.state == .on && mode.indexOfSelectedItem != 0 && mode.indexOfSelectedItem != 3 && dateString(next.dateValue) < dateString(purchase.dateValue) { alert("续费/到期日不能早于购买日期"); return }
        var member = read("membership.json"); member["enabled"] = enabled.state == .on
        member["plan"] = planIDs[plan.indexOfSelectedItem]; member["tier"] = planTiers[plan.indexOfSelectedItem]
        if enabled.state == .on {
            member.removeValue(forKey: "date")
            member["purchaseDate"] = dateString(purchase.dateValue); member["kind"] = mode.indexOfSelectedItem == 2 ? "expiry" : "renewal"
            member["monthlyEstimate"] = mode.indexOfSelectedItem == 0; member["annualEstimate"] = mode.indexOfSelectedItem == 3; member["estimated"] = mode.indexOfSelectedItem == 0 || mode.indexOfSelectedItem == 3
            if mode.indexOfSelectedItem != 0 && mode.indexOfSelectedItem != 3 { member["date"] = dateString(next.dateValue) }
        }
        do { try write("membership.json", member); var prefs = read("preferences.json"); prefs["setupComplete"] = true; try write("preferences.json", prefs); showStatus(); if child == nil { start() } }
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
        guard !showingSettings, rows.count == 4 else { return }
        var state: [String: Any] = [:]
        if child?.isRunning == true { state = read("status.json") }
        // A stale status from a previous launch must never turn the startup indicator green.
        if let stamp = state["updatedAt"] as? String {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: stamp), date >= startedAt, abs(date.timeIntervalSinceNow) < 35 { stage = state["stage"] as? String ?? stage } else { state = [:] }
        }
        let mounted = stage.hasPrefix("mounted")
        headline.stringValue = mounted ? "已连接" : stage == "failed" ? "连接未完成" : stage == "stopped" ? "已停止" : "正在连接"
        headline.textColor = mounted ? green : .labelColor
        detail.stringValue = stage == "failed" ? String(errorText.prefix(240)) : mounted ? "本机侧栏已挂载" : "等待客户端与数据同步"
        rows[0].stringValue = mounted ? "已连接" : "未连接"
        for (index, key) in [(1, "quotaAvailable"), (2, "usageAvailable")] { rows[index].stringValue = (state[key] as? Bool).map { $0 ? "已同步" : "暂不可用" } ?? "--" }
        if let stamp = state["updatedAt"] as? String { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; rows[3].stringValue = f.date(from: stamp).map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .medium) } ?? "--" } else { rows[3].stringValue = "--" }
        retry.isEnabled = !stopping && !reconnecting && stage != "starting"
        if feedbackUntil > Date() { detail.stringValue = feedback }
        if mounted && !hiddenAfterMount { hiddenAfterMount = true; DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in if let self = self, self.stage.hasPrefix("mounted"), !self.showingSettings { self.window.orderOut(nil) } } }
    }
    @objc func refresh() { do { try Data("refresh".utf8).write(to: runtime.appendingPathComponent("refresh.request"), options: .atomic) } catch { alert(error.localizedDescription) } }
    @objc func reconnect() {
        guard !stopping, !reconnecting else { return }
        notify("正在重新连接，不会关闭 Codex")
        if child == nil { start(); return }
        do { try Data("reconnect".utf8).write(to: runtime.appendingPathComponent("background-stop.request"), options: .atomic); reconnecting = true; retry.isEnabled = false }
        catch { alert(error.localizedDescription) }
    }
    @objc func openCodex() {
        guard opening == nil else { notify("正在唤起 Codex，请稍候"); return }
        notify("正在唤起 Codex...")
        let process = Process(); process.executableURL = root.appendingPathComponent("runtime/node"); process.arguments = [root.appendingPathComponent("mac/launch.mjs").path,"--native-ui","--focus"]
        process.terminationHandler = { [weak self] p in DispatchQueue.main.async { self?.opening = nil; self?.notify(p.terminationStatus == 0 ? "已发送 Codex 唤起请求" : "无法唤起 Codex，请检查签名配置和安装位置") } }
        do { opening = process; try process.run() } catch { opening = nil; notify(error.localizedDescription) }
    }
    @objc func stop() {
        guard child?.isRunning == true else { NSApp.terminate(nil); return }
        do { try Data("stop".utf8).write(to: runtime.appendingPathComponent("background-stop.request"), options: .atomic); stopping = true
            stopTimer?.invalidate(); stopTimer = Timer.scheduledTimer(withTimeInterval: 40, repeats: false) { [weak self] _ in
                guard let self = self, self.child?.isRunning == true else { return }; self.stopping = false; self.alert("仍在等待启动检查结束。请稍后再次退出软件，Codex 不会被强行关闭。")
            }
        } catch { alert(error.localizedDescription) }
    }
    func alert(_ text: String) { let a = NSAlert(); a.messageText = "Codex Quota Sidebar"; a.informativeText = text; a.runModal() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { if child?.isRunning == true { stop(); return .terminateCancel }; return .terminateNow }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { present(); return true }
}
let app = NSApplication.shared
let delegate = QuotaApp()
app.delegate = delegate
app.run()
