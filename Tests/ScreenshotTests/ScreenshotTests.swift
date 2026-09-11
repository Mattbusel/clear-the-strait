import XCTest

/// Drives the game to produce the App Store screenshots.
///
/// The round is live physics, so the shots are taken on a clock rather than by
/// waiting for a specific state. That is fine here: every second of a round
/// looks like the game, which is the point of a single-mechanic arcade toy.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // @MainActor because SnapshotHelper's setupSnapshot and snapshot are main
    // actor isolated, and calling them from a nonisolated test method is a hard
    // compile error under Swift 6 concurrency checking.
    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        sleep(2)
        snapshot("01_Title")

        app.buttons["PLAY"].firstMatch.tap()
        sleep(3)

        // Shove him about so the shots have motion, combo text and impact
        // particles in them rather than a stationary ball.
        let frame = app.windows.firstMatch.frame
        let leftOfHim = CGPoint(x: frame.width * 0.22, y: frame.height * 0.5)
        let rightOfHim = CGPoint(x: frame.width * 0.62, y: frame.height * 0.5)

        for i in 0..<10 {
            let target = i % 2 == 0 ? leftOfHim : rightOfHim
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: target.x, dy: target.y))
                .tap()
            usleep(180_000)
        }
        snapshot("02_Rolling")

        // Later in the round the bubbles and ships are up.
        sleep(12)
        for i in 0..<8 {
            let target = i % 2 == 0 ? leftOfHim : rightOfHim
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: target.x, dy: target.y))
                .tap()
            usleep(200_000)
        }
        snapshot("03_Ego")

        sleep(14)
        snapshot("04_Tremendous")
    }

    /// A full round at normal difficulty, for the App Review screen recording.
    ///
    /// Starts on the home screen so the video opens with the app launching.
    /// The workflow starts recording a few seconds after this runner appears,
    /// which lands inside the pause on the home screen.
    @MainActor
    func testReviewRecording() throws {
        XCUIDevice.shared.press(.home)
        sleep(9)

        let app = XCUIApplication()
        app.launchArguments += ["-demoAutoplay"]
        app.launch()
        sleep(3)

        app.buttons["PLAY"].firstMatch.tap()

        let again = app.buttons["PLAY AGAIN"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 180), "round never finished")
        sleep(5)

        app.buttons["TITLE"].firstMatch.tap()
        sleep(3)
    }

    /// The launch, captured on its own run.
    ///
    /// Reaching it honestly takes a minute of well-timed play, which a UI test
    /// cannot perform, so the app is started with -fastLaunch to lower the bar.
    /// This is the shot the whole game builds to and the one a store listing
    /// most needs.
    @MainActor
    func testCaptureLaunch() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-fastLaunch"]
        app.launch()

        app.buttons["PLAY"].firstMatch.tap()
        sleep(2)

        let frame = app.windows.firstMatch.frame
        for i in 0..<14 {
            let x = i % 2 == 0 ? frame.width * 0.24 : frame.width * 0.64
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: x, dy: frame.height * 0.5))
                .tap()
            usleep(140_000)
        }
        // Mid-flight, while he is still skipping and shouting.
        sleep(2)
        snapshot("05_Launch")

        // And the payoff screen.
        sleep(4)
        snapshot("06_Result")
    }
}
