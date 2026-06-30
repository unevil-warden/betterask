import XCTest
@testable import BetterAskVoice

final class RefinerPromptTests: XCTestCase {

    func testFaithfulPromptCarriesCoreInvariants() {
        let prompt = RefinePrompt.faithful.lowercased()
        XCTAssertTrue(prompt.contains("preserve the speaker's intent"))
        XCTAssertTrue(prompt.contains("do not answer the prompt"))
        XCTAssertTrue(prompt.contains("do not add"))
        XCTAssertTrue(prompt.contains("output only the rewritten prompt"))
        // Additions, if any, must be surfaced via the labeled assumptions marker.
        XCTAssertTrue(prompt.contains(RefinePrompt.assumptionsSentinel.lowercased()))
    }

    func testEnhancePromptCarriesCoreInvariants() {
        let prompt = RefinePrompt.enhance.lowercased()
        XCTAssertTrue(prompt.contains("do not answer the prompt"))
        XCTAssertTrue(prompt.contains("must not go into the prompt body"))
        XCTAssertTrue(prompt.contains(RefinePrompt.assumptionsSentinel.lowercased()))
    }

    func testSelectorReturnsMatchingPrompt() {
        XCTAssertEqual(RefinePrompt.system(for: .faithful), RefinePrompt.faithful)
        XCTAssertEqual(RefinePrompt.system(for: .enhance), RefinePrompt.enhance)
    }

    func testSentinelIsDistinctive() {
        XCTAssertEqual(RefinePrompt.assumptionsSentinel, "===ASSUMPTIONS===")
    }
}
