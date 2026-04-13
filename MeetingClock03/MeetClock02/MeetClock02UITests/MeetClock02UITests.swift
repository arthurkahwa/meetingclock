//
//  MeetClock02UITests.swift
//  MeetClock02UITests
//
//  Created by Arthur Nsereko Kahwa on 2026-02-02.
//

import XCTest

final class MeetClock02UITests: XCTestCase {
    // nonisolated(unsafe) because setUp/tearDown are nonisolated in XCTestCase;
    // XCTest guarantees serial main-thread execution so this is safe.
    nonisolated(unsafe) var app: XCUIApplication!

    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    nonisolated override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Add meeting

    @MainActor
    func testAddMeeting() throws {
        let addButton = app.buttons["Add Meeting"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.cells.count >= 1)
    }

    // MARK: - Delete meeting

    @MainActor
    func testDeleteMeeting() throws {
        let addButton = app.buttons["Add Meeting"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let initialCount = app.cells.count
        XCTAssertGreaterThan(initialCount, 0)

        app.cells.element(boundBy: 0).swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertEqual(app.cells.count, initialCount - 1)
    }

    // MARK: - Start and stop timer

    @MainActor
    func testStartAndStopTimer() throws {
        let addButton = app.buttons["Add Meeting"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let startButton = app.buttons["Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        sleep(2)
        let elapsedLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ':'")).firstMatch
        XCTAssertTrue(elapsedLabel.exists)
        XCTAssertNotEqual(elapsedLabel.label, "0:00:00")

        let stopButton = app.buttons["Stop"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 3))
        stopButton.tap()
    }

    // MARK: - Add participant from picker

    @MainActor
    func testAddParticipantFromPicker() throws {
        let addButton = app.buttons["Add Meeting"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let addParticipantButton = app.buttons["Add Participant"]
        XCTAssertTrue(addParticipantButton.waitForExistence(timeout: 3))
        addParticipantButton.tap()

        let newButton = app.buttons["New Participant"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 3))
        newButton.tap()

        let firstNameField = app.textFields["First Name"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 3))
        firstNameField.tap()
        firstNameField.typeText("Alice")

        app.swipeDown()
        XCTAssertTrue(app.staticTexts["Alice"].waitForExistence(timeout: 3))
    }
}
