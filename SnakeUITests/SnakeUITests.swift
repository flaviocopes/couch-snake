import XCTest

final class SnakeUITests: XCTestCase {
  @MainActor
  func testRemoteControlsTheGame() {
    let app = XCUIApplication()
    app.launch()
    let remote = XCUIRemote.shared

    XCTAssertTrue(app.staticTexts["Swipe to start"].waitForExistence(timeout: 10))
    attachScreenshot("ready")

    remote.press(.down)
    XCTAssertTrue(app.staticTexts["Swipe to start"].waitForNonExistence(timeout: 3))
    sleep(1)
    remote.press(.right)
    attachScreenshot("turning")

    remote.press(.playPause)
    XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 3))
    attachScreenshot("paused")

    remote.press(.select)
    XCTAssertTrue(app.staticTexts["PAUSED"].waitForNonExistence(timeout: 3))

    remote.press(.menu)
    XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 3))
  }

  @MainActor
  func testPlayPauseOpensThePlayers() {
    let app = XCUIApplication()
    app.launch()
    let remote = XCUIRemote.shared

    XCTAssertTrue(app.staticTexts["Play/Pause for players"].waitForExistence(timeout: 10))
    remote.press(.playPause)
    XCTAssertTrue(app.staticTexts["PLAYERS"].waitForExistence(timeout: 3))
    attachScreenshot("players")

    remote.press(.down)
    remote.press(.select)
    XCTAssertTrue(app.alerts["New player"].waitForExistence(timeout: 3))
    attachScreenshot("new player")
    remote.press(.menu)
    XCTAssertTrue(app.alerts["New player"].waitForNonExistence(timeout: 3))

    remote.press(.menu)
    XCTAssertTrue(app.staticTexts["PLAYERS"].waitForNonExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Swipe to start"].exists, "Play/Pause started the game")
  }

  @MainActor
  private func attachScreenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
