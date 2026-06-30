import XCTest
@testable import BetterAskVoice

final class RefineGateTests: XCTestCase {

    func testShortCleanPromptIsNotRefined() {
        XCTAssertFalse(RefineGate.shouldRefine("Write a haiku about the sea."))
    }

    func testEmptyOrWhitespaceIsNotRefined() {
        XCTAssertFalse(RefineGate.shouldRefine(""))
        XCTAssertFalse(RefineGate.shouldRefine("    \n  "))
    }

    func testShortPromptUnderWordThresholdIsNotRefined() {
        // Has filler but only a few words → not worth a model call.
        XCTAssertFalse(RefineGate.shouldRefine("um like okay so yeah"))
    }

    func testLongFillerHeavyTranscriptIsRefined() {
        let transcript = "okay so like um i need you to uh basically make this thing "
            + "work you know and like actually i mean it should kind of just do "
            + "the stuff i described before sort of"
        XCTAssertTrue(RefineGate.shouldRefine(transcript))
    }

    func testRunOnWithoutPunctuationIsRefined() {
        // More than 35 distinct words, no period, no filler, no adjacent repeats
        // → only the run-on signal fires.
        let transcript = (1...40).map { "word\($0)" }.joined(separator: " ")
        XCTAssertTrue(RefineGate.shouldRefine(transcript))
    }

    func testAdjacentRepetitionIsRefined() {
        let transcript = "please please review the the code and tell me what is "
            + "going on with this whole entire thing right now"
        XCTAssertTrue(RefineGate.shouldRefine(transcript))
    }
}
