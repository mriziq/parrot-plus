import XCTest
@testable import ParrotCore

final class LastTranscriptTests: XCTestCase {
    func testStartsEmptyAndUpdatesWithDeliveredText() {
        var transcript = LastTranscript()
        XCTAssertNil(transcript.text)

        transcript.update("hello there")

        XCTAssertEqual(transcript.text, "hello there")
    }

    func testEmptyTranscriptDoesNotErasePreviousValue() {
        var transcript = LastTranscript()
        transcript.update("hello there")

        transcript.update("")

        XCTAssertEqual(transcript.text, "hello there")
    }
}
