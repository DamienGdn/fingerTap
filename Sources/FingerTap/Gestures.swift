import FingerTapCore
import Foundation

extension Gesture {
    var label: String {
        switch self {
        case .doubleTap: String(localized: "Double tap")
        case .swipeUp: String(localized: "Swipe up")
        case .swipeDown: String(localized: "Swipe down")
        case .swipeLeft: String(localized: "Swipe left")
        case .swipeRight: String(localized: "Swipe right")
        }
    }

    var symbol: String {
        switch self {
        case .doubleTap: "hand.tap"
        case .swipeUp: "arrow.up"
        case .swipeDown: "arrow.down"
        case .swipeLeft: "arrow.left"
        case .swipeRight: "arrow.right"
        }
    }

    func title(fingers: Int) -> String {
        switch self {
        case .doubleTap: String(localized: "\(fingers)-finger double tap")
        case .swipeUp: String(localized: "\(fingers)-finger swipe up")
        case .swipeDown: String(localized: "\(fingers)-finger swipe down")
        case .swipeLeft: String(localized: "\(fingers)-finger swipe left")
        case .swipeRight: String(localized: "\(fingers)-finger swipe right")
        }
    }
}

/// macOS trackpad gestures, read from System Settings, that fire on the same movement as ours.
/// FingerTap only listens: it cannot stop them, so both would happen.
enum SystemGestures {
    private static let trackpadDomains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]

    /// What macOS also does on this gesture, or nil when it is free.
    static func conflict(_ gesture: Gesture, fingers: Int) -> String? {
        let prefix: String
        switch fingers {
        case 3: prefix = "TrackpadThreeFinger"
        case 4: prefix = "TrackpadFourFinger"
        default: return nil
        }
        let dock = UserDefaults(suiteName: "com.apple.dock")
        switch gesture {
        case .doubleTap:
            guard fingers == 3, isOn("TrackpadThreeFingerTapGesture") else { return nil }
            return String(localized: "macOS also runs Look Up on each 3-finger tap.")
        case .swipeUp:
            guard isOn(prefix + "VertSwipeGesture"), dock?.object(forKey: "showMissionControlGestureEnabled") as? Bool ?? true
            else { return nil }
            return String(localized: "macOS also opens Mission Control. Change it in System Settings > Trackpad > More Gestures.")
        case .swipeDown:
            guard isOn(prefix + "VertSwipeGesture"), dock?.bool(forKey: "showAppExposeGestureEnabled") == true else { return nil }
            return String(localized: "macOS also opens App Exposé. Change it in System Settings > Trackpad > More Gestures.")
        case .swipeLeft, .swipeRight:
            guard isOn(prefix + "HorizSwipeGesture") else { return nil }
            return String(localized: "macOS also switches pages or full-screen apps. Change it in System Settings > Trackpad > More Gestures.")
        }
    }

    private static func isOn(_ key: String) -> Bool {
        trackpadDomains.contains { (UserDefaults(suiteName: $0)?.integer(forKey: key) ?? 0) != 0 }
    }
}
