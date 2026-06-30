import XCTest
@testable import BetterAskVoice

final class IntentParsingTests: XCTestCase {

    func testNoSentinelMeansWholeReplyIsPrompt() {
        let out = AnthropicRefiner.parse("Fix the login flow.")
        XCTAssertEqual(out.prompt, "Fix the login flow.")
        XCTAssertTrue(out.assumptions.isEmpty)
    }

    func testSentinelSplitsPromptFromAssumptions() {
        let raw = """
        Fix the web login flow.
        ===ASSUMPTIONS===
        - Assumed web, not mobile
        - Assumed the bug is in auth
        """
        let out = AnthropicRefiner.parse(raw)
        XCTAssertEqual(out.prompt, "Fix the web login flow.")
        XCTAssertEqual(out.assumptions, ["Assumed web, not mobile", "Assumed the bug is in auth"])
    }

    func testToleratesMissingDashSpaceAndBlankLines() {
        let raw = "Do the thing.\n===ASSUMPTIONS===\n-No space after dash\n\n- spaced item\n"
        let out = AnthropicRefiner.parse(raw)
        XCTAssertEqual(out.prompt, "Do the thing.")
        XCTAssertEqual(out.assumptions, ["No space after dash", "spaced item"])
    }

    func testSentinelWithNoAssumptionsListedYieldsEmpty() {
        let raw = "Just the prompt.\n===ASSUMPTIONS===\n   \n"
        let out = AnthropicRefiner.parse(raw)
        XCTAssertEqual(out.prompt, "Just the prompt.")
        XCTAssertTrue(out.assumptions.isEmpty)
    }
}
