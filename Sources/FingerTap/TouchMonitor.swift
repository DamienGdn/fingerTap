import FingerTapCore
import Foundation
import IOKit
import MultitouchBridge
import os

let log = Logger(subsystem: "local.fingertap.app", category: "taps")

/// Called by MultitouchSupport on its own thread for every frame of every trackpad.
private let frameCallback: MTFrameCallback = { device, touches, count, timestamp, _ in
    TouchMonitor.shared.receive(device: device, touches: touches, count: Int(count), timestamp: timestamp)
    return 0
}

/// Reads every trackpad and reports gestures (double taps and swipes). Restarts itself when a trackpad appears
/// (Bluetooth reconnection) or the Mac wakes, since MultitouchSupport drops devices then.
final class TouchMonitor: @unchecked Sendable {
    static let shared = TouchMonitor()

    /// Called on a background thread for each recognized gesture. Set before `start()`.
    var onGesture: (@Sendable (Gesture, Int) -> Void)?

    /// MTTouch states of a finger in contact: make touch, touching, break touch. The others are
    /// fingers hovering before or after contact, which would stretch every tap.
    private static let contactStates: ClosedRange<Int32> = 3...5

    private let lock = NSLock()
    private var detectors: [UnsafeMutableRawPointer: GestureDetector] = [:]
    private var notificationPort: IONotificationPortRef?

    /// Returns the number of trackpads found, or -1 when MultitouchSupport is unavailable.
    @discardableResult
    func start() -> Int {
        lock.withLock { detectors = [:] }
        return Int(MTBridgeStart(frameCallback))
    }

    fileprivate func receive(device: MTDeviceRef?, touches: UnsafePointer<MTTouch>?, count: Int, timestamp: Double) {
        guard let device else { return }
        var points: [TouchPoint] = []
        if let touches {
            points.reserveCapacity(count)
            for index in 0..<count {
                let touch = touches[index]
                guard Self.contactStates.contains(touch.state) else { continue }
                points.append(TouchPoint(id: touch.identifier, x: touch.normalized.position.x, y: touch.normalized.position.y))
            }
        }
        let result = lock.withLock {
            var detector = detectors[device] ?? GestureDetector()
            defer { detectors[device] = detector }
            return detector.feed(points, at: timestamp)
        }
        if let touchdown = result.touchdown, touchdown.fingers >= 2 {
            log.debug("""
                touchdown fingers=\(touchdown.fingers) duration=\(touchdown.duration, format: .fixed(precision: 3)) \
                movement=\(touchdown.movement, format: .fixed(precision: 3)) \
                dx=\(touchdown.dx, format: .fixed(precision: 3)) dy=\(touchdown.dy, format: .fixed(precision: 3)) \
                tap=\(touchdown.isTap) swipe=\(touchdown.swipe?.rawValue ?? "-", privacy: .public)
                """)
        }
        if let (gesture, fingers) = result.gesture { onGesture?(gesture, fingers) }
    }

    /// Calls `onChange` on the main thread whenever a multitouch device is plugged in or paired.
    func watchDevices(onChange: @escaping () -> Void) {
        guard notificationPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notificationPort = port
        DeviceWatcher.onChange = onChange
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        var iterator: io_iterator_t = 0
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("AppleMultitouchDevice"),
                                         { _, iterator in
                                             DeviceWatcher.drain(iterator)
                                             DeviceWatcher.onChange?()
                                         }, nil, &iterator)
        // Devices already present: draining arms the notification without restarting.
        DeviceWatcher.drain(iterator)
    }
}

private enum DeviceWatcher {
    nonisolated(unsafe) static var onChange: (() -> Void)?

    static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}
