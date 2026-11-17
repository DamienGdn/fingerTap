import FingerTapCore
import XCTest

private func fingers(_ count: Int, dx: Float = 0, dy: Float = 0) -> [TouchPoint] {
    (0..<count).map { TouchPoint(id: Int32($0), x: 0.2 + Float($0) * 0.1 + dx, y: 0.5 + dy) }
}

final class TouchdownDetectorTests: XCTestCase {
    func testFourFingerTap() {
        var detector = TouchdownDetector()
        XCTAssertNil(detector.feed(fingers(2), at: 0))
        XCTAssertNil(detector.feed(fingers(4), at: 0.03))
        XCTAssertNil(detector.feed(fingers(1), at: 0.15))
        let touchdown = detector.feed([], at: 0.18)
        XCTAssertEqual(touchdown?.fingers, 4)
        XCTAssertEqual(touchdown?.isTap, true)
        XCTAssertNil(touchdown?.swipe)
    }

    func testLongPressIsNeitherTapNorSwipe() {
        var detector = TouchdownDetector()
        _ = detector.feed(fingers(4), at: 0)
        let touchdown = detector.feed([], at: 0.8)
        XCTAssertEqual(touchdown?.isTap, false)
        XCTAssertNil(touchdown?.swipe)
    }

    func testSwipeDirections() {
        for (dx, dy, expected) in [(Float(0), Float(-0.3), Gesture.swipeDown), (0, 0.3, .swipeUp),
                                   (-0.3, 0, .swipeLeft), (0.3, 0.02, .swipeRight)] {
            var detector = TouchdownDetector()
            _ = detector.feed(fingers(3), at: 0)
            _ = detector.feed(fingers(3, dx: dx / 2, dy: dy / 2), at: 0.1)
            _ = detector.feed(fingers(3, dx: dx, dy: dy), at: 0.2)
            let touchdown = detector.feed([], at: 0.25)
            XCTAssertEqual(touchdown?.swipe, expected, "\(dx), \(dy)")
            XCTAssertEqual(touchdown?.isTap, false)
        }
    }

    func testDiagonalIsNotASwipe() {
        var detector = TouchdownDetector()
        _ = detector.feed(fingers(3), at: 0)
        _ = detector.feed(fingers(3, dx: 0.2, dy: -0.2), at: 0.2)
        XCTAssertNil(detector.feed([], at: 0.25)?.swipe)
    }

    func testShortSlideIsNotASwipe() {
        var detector = TouchdownDetector()
        _ = detector.feed(fingers(3), at: 0)
        _ = detector.feed(fingers(3, dy: -0.08), at: 0.2)
        XCTAssertNil(detector.feed([], at: 0.25)?.swipe)
    }
}

final class GestureDetectorTests: XCTestCase {
    private func tap(_ detector: inout GestureDetector, fingers count: Int, at time: TimeInterval) -> Gesture? {
        _ = detector.feed(fingers(count), at: time)
        return detector.feed([], at: time + 0.1).gesture?.gesture
    }

    func testDoubleTap() {
        var detector = GestureDetector()
        XCTAssertNil(tap(&detector, fingers: 4, at: 0))
        XCTAssertEqual(tap(&detector, fingers: 4, at: 0.3), .doubleTap)
    }

    func testSlowTapsAreNotADoubleTap() {
        var detector = GestureDetector()
        XCTAssertNil(tap(&detector, fingers: 4, at: 0))
        XCTAssertNil(tap(&detector, fingers: 4, at: 1.5))
    }

    func testFingerCountsMustMatch() {
        var detector = GestureDetector()
        XCTAssertNil(tap(&detector, fingers: 3, at: 0))
        XCTAssertNil(tap(&detector, fingers: 4, at: 0.3))
    }

    func testTripleTapFiresOnce() {
        var detector = GestureDetector()
        XCTAssertNil(tap(&detector, fingers: 4, at: 0))
        XCTAssertEqual(tap(&detector, fingers: 4, at: 0.3), .doubleTap)
        XCTAssertNil(tap(&detector, fingers: 4, at: 0.6))
    }

    func testTwoFingerGesturesAreIgnored() {
        var detector = GestureDetector()
        XCTAssertNil(tap(&detector, fingers: 2, at: 0))
        XCTAssertNil(tap(&detector, fingers: 2, at: 0.3))
        _ = detector.feed(fingers(2), at: 1)
        _ = detector.feed(fingers(2, dy: -0.3), at: 1.2)
        XCTAssertNil(detector.feed([], at: 1.25).gesture)
    }

    func testSwipeReportsFingersAndCancelsPendingTap() {
        var detector = GestureDetector()
        XCTAssertNil(tap(&detector, fingers: 3, at: 0))
        _ = detector.feed(fingers(3), at: 0.2)
        _ = detector.feed(fingers(3, dy: -0.3), at: 0.4)
        let result = detector.feed([], at: 0.45).gesture
        XCTAssertEqual(result?.gesture, .swipeDown)
        XCTAssertEqual(result?.fingers, 3)
        XCTAssertNil(tap(&detector, fingers: 3, at: 0.6))
    }
}

final class ConfigurationTests: XCTestCase {
    func testInitialConfiguration() {
        let configuration = Configuration.initial(wKeyCode: 6, rKeyCode: 15)
        XCTAssertEqual(configuration.shortcut(.swipeDown, fingers: 3, bundleID: "com.google.Chrome")?.display, "⌘W")
        XCTAssertEqual(configuration.shortcut(.swipeUp, fingers: 3, bundleID: "com.google.Chrome")?.display, "⇧⌘R")
        XCTAssertNil(configuration.shortcut(.doubleTap, fingers: 3, bundleID: "com.google.Chrome"))
        XCTAssertNil(configuration.shortcut(.swipeDown, fingers: 3, bundleID: "com.apple.Safari"))
    }

    func testEditingRules() {
        var configuration = Configuration()
        XCTAssertTrue(configuration.addApp(bundleID: "com.apple.Safari", name: "Safari"))
        XCTAssertFalse(configuration.addApp(bundleID: "com.apple.Safari", name: "Safari"))
        let reopen = KeyShortcut(keyCode: 17, modifiers: [.command, .shift], key: "T")
        configuration.setShortcut(reopen, for: .swipeLeft, fingers: 3, bundleID: "com.apple.Safari")
        XCTAssertEqual(configuration.shortcut(.swipeLeft, fingers: 3, bundleID: "com.apple.Safari")?.display, "⇧⌘T")
        XCTAssertNil(configuration.shortcut(.doubleTap, fingers: 3, bundleID: "com.apple.Safari"))
        configuration.setShortcut(nil, for: .swipeLeft, fingers: 3, bundleID: "com.apple.Safari")
        XCTAssertNil(configuration.shortcut(.swipeLeft, fingers: 3, bundleID: "com.apple.Safari"))
        configuration.removeApp(bundleID: "com.apple.Safari")
        XCTAssertTrue(configuration.rules.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let configuration = Configuration.initial(wKeyCode: 13, rKeyCode: 15)
        let decoded = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        XCTAssertEqual(decoded, configuration)
    }

    func testBindingsSavedBeforeSwipesAreDoubleTaps() throws {
        let saved = #"{"rules":[{"bundleID":"a","name":"A","bindings":[{"fingers":4,"shortcut":{"keyCode":6,"modifiers":8,"key":"W"}}]}]}"#
        let configuration = try JSONDecoder().decode(Configuration.self, from: Data(saved.utf8))
        XCTAssertEqual(configuration.shortcut(.doubleTap, fingers: 4, bundleID: "a")?.display, "⌘W")
    }

    func testModifierSymbolsFollowAppleOrder() {
        XCTAssertEqual(Modifiers([.command, .shift, .control, .option]).symbols, "⌃⌥⇧⌘")
    }
}
