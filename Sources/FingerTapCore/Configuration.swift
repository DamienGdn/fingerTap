import Foundation

public enum Gesture: String, Codable, CaseIterable, Hashable, Sendable {
    case doubleTap, swipeUp, swipeDown, swipeLeft, swipeRight
}

public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 1)
    public static let option = Modifiers(rawValue: 2)
    public static let shift = Modifiers(rawValue: 4)
    public static let command = Modifiers(rawValue: 8)

    /// Apple's order: ⌃⌥⇧⌘.
    public var symbols: String {
        [(Modifiers.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }.map(\.1).joined()
    }
}

/// A keyboard shortcut to send. `keyCode` is the physical key, so it is replayed
/// with the keyboard layout it was recorded with; `key` is only its label.
public struct KeyShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Modifiers
    public var key: String

    public init(keyCode: UInt16, modifiers: Modifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    public var display: String { modifiers.symbols + key }
}

public struct GestureBinding: Codable, Hashable, Sendable {
    public var gesture: Gesture
    public var fingers: Int
    public var shortcut: KeyShortcut

    public init(gesture: Gesture, fingers: Int, shortcut: KeyShortcut) {
        self.gesture = gesture
        self.fingers = fingers
        self.shortcut = shortcut
    }

    private enum CodingKeys: String, CodingKey { case gesture, fingers, shortcut }

    /// Bindings saved before swipes existed have no gesture: they were double taps.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gesture = try container.decodeIfPresent(Gesture.self, forKey: .gesture) ?? .doubleTap
        fingers = try container.decode(Int.self, forKey: .fingers)
        shortcut = try container.decode(KeyShortcut.self, forKey: .shortcut)
    }
}

/// What gestures do while one app is frontmost.
public struct AppRule: Codable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var name: String
    public var bindings: [GestureBinding]
    public var id: String { bundleID }

    public init(bundleID: String, name: String, bindings: [GestureBinding] = []) {
        self.bundleID = bundleID
        self.name = name
        self.bindings = bindings
    }

    public func shortcut(_ gesture: Gesture, fingers: Int) -> KeyShortcut? {
        bindings.first { $0.gesture == gesture && $0.fingers == fingers }?.shortcut
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public var rules: [AppRule]

    public init(rules: [AppRule] = []) {
        self.rules = rules
    }

    /// Chrome: 3-finger swipe down closes the tab (⌘W), swipe up reloads ignoring the cache (⇧⌘R).
    /// Key codes are the physical keys typing W and R with the current layout.
    public static func initial(wKeyCode: UInt16, rKeyCode: UInt16) -> Configuration {
        Configuration(rules: [
            AppRule(bundleID: "com.google.Chrome", name: "Google Chrome", bindings: [
                GestureBinding(gesture: .swipeDown, fingers: 3,
                               shortcut: KeyShortcut(keyCode: wKeyCode, modifiers: .command, key: "W")),
                GestureBinding(gesture: .swipeUp, fingers: 3,
                               shortcut: KeyShortcut(keyCode: rKeyCode, modifiers: [.command, .shift], key: "R")),
            ]),
        ])
    }

    public func shortcut(_ gesture: Gesture, fingers: Int, bundleID: String) -> KeyShortcut? {
        rules.first { $0.bundleID == bundleID }?.shortcut(gesture, fingers: fingers)
    }

    /// Adds an app with no action yet. Returns false when it is already configured.
    @discardableResult
    public mutating func addApp(bundleID: String, name: String) -> Bool {
        guard !rules.contains(where: { $0.bundleID == bundleID }) else { return false }
        rules.append(AppRule(bundleID: bundleID, name: name))
        rules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return true
    }

    public mutating func removeApp(bundleID: String) {
        rules.removeAll { $0.bundleID == bundleID }
    }

    /// Sets, replaces or (with nil) removes the shortcut of a gesture in an app.
    public mutating func setShortcut(_ shortcut: KeyShortcut?, for gesture: Gesture, fingers: Int, bundleID: String) {
        guard let index = rules.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        rules[index].bindings.removeAll { $0.gesture == gesture && $0.fingers == fingers }
        if let shortcut {
            rules[index].bindings.append(GestureBinding(gesture: gesture, fingers: fingers, shortcut: shortcut))
        }
    }
}
