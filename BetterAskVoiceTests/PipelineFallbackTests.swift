import XCTest
@testable import BetterAskVoice

// MARK: - Test doubles

private struct ThrowingRefiner: PromptRefiner {
    func refine(transcript: String, mode: IntentMode) async throws -> RefinementOutput {
        throw URLError(.timedOut)
    }
}

private struct EmptyRefiner: PromptRefiner {
    func refine(transcript: String, mode: IntentMode) async throws -> RefinementOutput {
        RefinementOutput(prompt: "   ", assumptions: [])
    }
}

private struct StubRefiner: PromptRefiner {
    let output: RefinementOutput
    func refine(transcript: String, mode: IntentMode) async throws -> RefinementOutput {
        output
    }
}

final class PipelineFallbackTests: XCTestCase {

    /// A transcript the gate will choose to refine (filler-heavy, long).
    private let messy = "okay so like um i need you to uh basically make this whole "
        + "thing work you know and like actually fix it"

    func testRefinerFailureFallsBackToRawTranscript() async throws {
        let pipeline = VoicePipeline(refiner: ThrowingRefiner(), config: .default)
        let result = try await pipeline.refine(rawTranscript: messy)

        XCTAssertFalse(result.usedRefinement)
        XCTAssertEqual(result.refinedPrompt, messy)
        XCTAssertNil(result.refinementProvider)
        XCTAssertTrue(result.warnings.contains("refinement_failed_used_raw_transcript"))
    }

    func testEmptyRefinementFallsBackToRawTranscript() async throws {
        let pipeline = VoicePipeline(refiner: EmptyRefiner(), config: .default)
        let result = try await pipeline.refine(rawTranscript: messy)

        XCTAssertFalse(result.usedRefinement)
        XCTAssertEqual(result.refinedPrompt, messy)
        XCTAssertTrue(result.warnings.contains("refinement_returned_empty_used_raw_transcript"))
    }

    func testNoRefinerUsesRawTranscript() async throws {
        let pipeline = VoicePipeline(refiner: nil, config: .default)
        let result = try await pipeline.refine(rawTranscript: messy)

        XCTAssertFalse(result.usedRefinement)
        XCTAssertEqual(result.refinedPrompt, messy)
        XCTAssertTrue(result.warnings.contains("refinement_unavailable_used_raw_transcript"))
    }

    func testCleanTranscriptSkipsRefiner() async throws {
        let stub = StubRefiner(output: .init(prompt: "SHOULD NOT BE USED", assumptions: []))
        let pipeline = VoicePipeline(refiner: stub, config: .default)
        let result = try await pipeline.refine(rawTranscript: "Write a haiku about the sea.")

        XCTAssertFalse(result.usedRefinement)
        XCTAssertEqual(result.refinedPrompt, "Write a haiku about the sea.")
        XCTAssertTrue(result.warnings.contains("refinement_skipped_clean_transcript"))
    }

    func testSuccessfulRefinementCarriesAssumptionsAndProvider() async throws {
        let stub = StubRefiner(output: .init(
            prompt: "Fix the web login flow.",
            assumptions: ["Assumed web, not mobile"]
        ))
        let pipeline = VoicePipeline(refiner: stub, config: .default)
        let result = try await pipeline.refine(rawTranscript: messy)

        XCTAssertTrue(result.usedRefinement)
        XCTAssertEqual(result.refinedPrompt, "Fix the web login flow.")
        XCTAssertEqual(result.assumptions, ["Assumed web, not mobile"])
        XCTAssertEqual(result.refinementProvider, "anthropic")
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testEmptyTranscriptThrows() async {
        let stub = StubRefiner(output: .init(prompt: "x", assumptions: []))
        let pipeline = VoicePipeline(refiner: stub, config: .default)
        do {
            _ = try await pipeline.refine(rawTranscript: "    ")
            XCTFail("Expected an empty-transcript error")
        } catch {
            // expected
        }
    }
}
