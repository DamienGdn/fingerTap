import AppKit
import ApplicationServices
import FingerTapCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    private static let configurationKey = "configuration"
    private static let enabledKey = "enabled"

    @Published var configuration: Configuration {
        didSet { save() }
    }
    @Published var isEnabled = UserDefaults.standard.object(forKey: AppModel.enabledKey) as? Bool ?? true {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var trackpadCount = 0
    @Published private(set) var lastEvent: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.configurationKey),
           let saved = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = saved
        } else {
            configuration = .initial(wKeyCode: Keyboard.keyCode(typing: "w") ?? 13, rKeyCode: Keyboard.keyCode(typing: "r") ?? 15)
        }

        let monitor = TouchMonitor.shared
        monitor.onGesture = { [weak self] gesture, fingers in
            Task { @MainActor in self?.handle(gesture, fingers: fingers) }
        }
        trackpadCount = monitor.start()
        monitor.watchDevices { [weak self] in self?.restartSoon() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restartSoon() }
        }

        // The Accessibility permission is granted in System Settings, outside the app: poll it.
        Task { [weak self] in
            while let self {
                self.isTrusted = AXIsProcessTrusted()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: Self.configurationKey)
        }
    }

    private func restartSoon() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            trackpadCount = TouchMonitor.shared.start()
        }
    }

    // MARK: Gestures

    private func handle(_ gesture: Gesture, fingers: Int) {
        guard isEnabled else { return }
        let app = NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "?"
        guard let bundleID = app?.bundleIdentifier,
              let shortcut = configuration.shortcut(gesture, fingers: fingers, bundleID: bundleID) else {
            lastEvent = String(localized: "\(gesture.title(fingers: fingers)) in \(name): no action")
            log.info("\(gesture.rawValue, privacy: .public) \(fingers) in \(name, privacy: .public): no action")
            return
        }
        guard isTrusted else {
            lastEvent = String(localized: "\(gesture.title(fingers: fingers)) in \(name): Accessibility permission missing")
            log.info("\(gesture.rawValue, privacy: .public) \(fingers) in \(name, privacy: .public): not trusted")
            return
        }
        Keyboard.send(shortcut)
        lastEvent = String(localized: "\(gesture.title(fingers: fingers)) in \(name): \(shortcut.display)")
        log.info("\(gesture.rawValue, privacy: .public) \(fingers) in \(name, privacy: .public): sent \(shortcut.display, privacy: .public)")
    }

    // MARK: Settings

    func requestAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if !AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            lastEvent = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Asks for an app to configure. Returns its bundle id, nil when cancelled or invalid.
    func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: "Add")
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        configuration.addApp(bundleID: bundleID, name: name)
        return bundleID
    }
}
