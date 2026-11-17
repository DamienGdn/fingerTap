import Foundation

/// One finger touching the trackpad in one frame, position normalized to 0...1 (y grows upward).
public struct TouchPoint: Sendable {
    public let id: Int32
    public let x: Float
    public let y: Float

    public init(id: Int32, x: Float, y: Float) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Everything that happened between the first finger landing and the last one lifting.
public struct Touchdown: Equatable, Sendable {
    public let fingers: Int
    public let duration: TimeInterval
    /// Largest distance travelled by one finger.
    public let movement: Float
    /// Average travel of the fingers, from where they landed to where they lifted.
    public let dx: Float
    public let dy: Float
    public let end: TimeInterval
    public let isTap: Bool
    /// Direction of a clear, quick slide; nil otherwise.
    public let swipe: Gesture?
}

/// Splits trackpad frames into touchdowns and classifies them as taps, swipes or neither.
public struct TouchdownDetector: Sendable {
    public var maxTapDuration: TimeInterval = 0.35
    /// Largest distance a finger may travel during a tap, as a share of the trackpad size.
    public var maxTapMovement: Float = 0.06
    public var maxSwipeDuration: TimeInterval = 1.0
    public var minSwipeDistance: Float = 0.12
    /// The main axis must carry at least this many times the travel of the other one.
    public var swipeAxisRatio: Float = 2

    private var startTime: TimeInterval?
    private var origins: [Int32: (x: Float, y: Float)] = [:]
    private var latest: [Int32: (x: Float, y: Float)] = [:]
    private var maxFingers = 0
    private var movement: Float = 0

    public init() {}

    /// Feeds one frame. Returns the touchdown when this frame has no finger left after some had landed.
    public mutating func feed(_ touches: [TouchPoint], at time: TimeInterval) -> Touchdown? {
        guard !touches.isEmpty else {
            guard let startTime else { return nil }
            defer { reset() }
            return finish(duration: time - startTime, end: time)
        }
        if startTime == nil { startTime = time }
        maxFingers = max(maxFingers, touches.count)
        for touch in touches {
            if let origin = origins[touch.id] {
                movement = max(movement, hypot(touch.x - origin.x, touch.y - origin.y))
            } else {
                origins[touch.id] = (touch.x, touch.y)
            }
            latest[touch.id] = (touch.x, touch.y)
        }
        return nil
    }

    private func finish(duration: TimeInterval, end: TimeInterval) -> Touchdown {
        let count = Float(max(1, origins.count))
        var dx: Float = 0
        var dy: Float = 0
        for (id, origin) in origins {
            guard let last = latest[id] else { continue }
            dx += (last.x - origin.x) / count
            dy += (last.y - origin.y) / count
        }
        var swipe: Gesture?
        if duration <= maxSwipeDuration {
            if abs(dy) >= minSwipeDistance, abs(dy) >= swipeAxisRatio * abs(dx) {
                swipe = dy > 0 ? .swipeUp : .swipeDown
            } else if abs(dx) >= minSwipeDistance, abs(dx) >= swipeAxisRatio * abs(dy) {
                swipe = dx > 0 ? .swipeRight : .swipeLeft
            }
        }
        return Touchdown(fingers: maxFingers, duration: duration, movement: movement, dx: dx, dy: dy, end: end,
                         isTap: duration <= maxTapDuration && movement <= maxTapMovement, swipe: swipe)
    }

    private mutating func reset() {
        startTime = nil
        origins = [:]
        latest = [:]
        maxFingers = 0
        movement = 0
    }
}

/// Recognizes the gestures FingerTap acts on, with 3 to 5 fingers: double taps
/// (two taps with the same number of fingers in quick succession) and swipes.
public struct GestureDetector: Sendable {
    public static let fingerRange = 3...5

    /// Longest pause between the end of the first tap and the end of the second.
    public var maxDoubleTapInterval: TimeInterval = 0.5

    private var touchdowns = TouchdownDetector()
    private var pendingTap: Touchdown?

    public init() {}

    /// Feeds one frame. Returns the touchdown it ended, if any, and the recognized gesture.
    public mutating func feed(_ touches: [TouchPoint], at time: TimeInterval)
        -> (touchdown: Touchdown?, gesture: (gesture: Gesture, fingers: Int)?) {
        guard let touchdown = touchdowns.feed(touches, at: time) else { return (nil, nil) }
        guard Self.fingerRange.contains(touchdown.fingers) else {
            pendingTap = nil
            return (touchdown, nil)
        }
        if let swipe = touchdown.swipe {
            pendingTap = nil
            return (touchdown, (swipe, touchdown.fingers))
        }
        guard touchdown.isTap else {
            pendingTap = nil
            return (touchdown, nil)
        }
        if let first = pendingTap, first.fingers == touchdown.fingers, touchdown.end - first.end <= maxDoubleTapInterval {
            pendingTap = nil
            return (touchdown, (.doubleTap, touchdown.fingers))
        }
        pendingTap = touchdown
        return (touchdown, nil)
    }
}
