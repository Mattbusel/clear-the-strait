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
}
