import Foundation

/// Output of a refinement call: the cleaned prompt plus any labeled assumptions
/// the model surfaced. Keeping assumptions separate is the core trust guarantee
/// — the UI shows them distinctly and the user chooses whether to include them.
struct RefinementOutput {
    let prompt: String
    let assumptions: [String]
}

/// Swappable refinement provider. An implementation rewrites a raw transcript
/// into a clean prompt under the given intent mode. A future on-device LLM
/// refiner can conform to this without changing the pipeline.
protocol PromptRefiner {
    func refine(transcript: String, mode: IntentMode) async throws -> RefinementOutput
}
