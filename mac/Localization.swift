import AppKit
enum CqsLocale {
    static let repository = URL(string: "https://github.com/kefen/codex-quota-sidebar")!
    static let modes = ["system","en","zh-CN","zh-TW"]
    static var mode: String { UserDefaults.standard.string(forKey: "cqs-language") ?? "system" }
    static func resolve(_ mode: String) -> String {
        let saved = mode == "system" ? (Locale.preferredLanguages.first ?? "en") : mode
        if saved.hasPrefix("zh") { return saved.contains("Hant") || saved.contains("TW") || saved.contains("HK") || saved.contains("MO") ? "zh-TW" : "zh-CN" }
        return "en"
    }
    static var language = resolve(mode)
    static let catalog: [String:[String]] = {
        let url = Bundle.main.url(forResource: "strings", withExtension: "json") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexSidebarMeter/ui/strings.json")
        let object = (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: [String]] } ?? [:]
        return object
    }()
    static let preferredCanonicalKeys = ["Credits", "Quota remaining", "Plan and dates", "Monthly daily average", "Display choices"]
    static func canonicalKey(_ text: String) -> String {
        if catalog[text] != nil { return text }
        if let preferred = preferredCanonicalKeys.first(where: { catalog[$0]?.contains(text) == true }) { return preferred }
        // Remaining aliases must also resolve consistently across Dictionary hash seeds.
        return catalog.keys.sorted().first(where: { catalog[$0]?.contains(text) == true }) ?? text
    }
    static func t(_ text: String) -> String {
        let key = canonicalKey(text)
        guard let values = catalog[key], values.count == 2 else { return text }
        return language == "en" ? key : values[language == "zh-TW" ? 1 : 0]
    }
    static func apply(_ view: NSView) {
        if let field = view as? NSTextField, !field.isEditable { field.stringValue = t(field.stringValue) }
        if let popup = view as? NSPopUpButton { if popup.identifier?.rawValue != "language" { for item in popup.itemArray { item.title = t(item.title) } } }
        else if let button = view as? NSButton, button.imagePosition != .imageOnly { button.title = t(button.title) }
        for child in view.subviews { apply(child) }
    }
}
