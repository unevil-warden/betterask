import Foundation

/// Result of one voice → prompt run. Swift port of the reference
/// `VoicePromptResult` dataclass, with two additions:
/// `assumptions` (anything the model inferred, surfaced separately) and
/// `intentMode` (which refinement mode produced it).
struct VoicePromptResult: Codable, Identifiable {
    let id = UUID()
    var rawTranscript: String
    var refinedPrompt: String
    /// Labeled guesses the refiner made when intent was unclear. Always shown
    /// to the user; never merged silently into `refinedPrompt`.
    var assumptions: [String]
    var usedRefinement: Bool
    var intentMode: IntentMode
    var transcriptionProvider: String
    var transcriptionModel: String
    var refinementProvider: String?
    var refinementModel: String?
    var warnings: [String]
    var metadata: [String: String]

    /// The text a user would copy/paste. Assumptions are appended only when the
    /// user opts to include them, and always under a clearly-labeled heading.
    func composedPrompt(includeAssumptions: Bool) -> String {
        guard includeAssumptions, !assumptions.isEmpty else { return refinedPrompt }
        let block = assumptions.map { "- \($0)" }.joined(separator: "\n")
        return "\(refinedPrompt)\n\nAssumptions (delete if wrong):\n\(block)"
    }

    // `id` is intentionally excluded from coding so JSON exports are stable and
    // round-trippable without a persisted identifier.
    enum CodingKeys: String, CodingKey {
        case rawTranscript, refinedPrompt, assumptions, usedRefinement, intentMode
        case transcriptionProvider, transcriptionModel, refinementProvider, refinementModel
        case warnings, metadata
    }
}
