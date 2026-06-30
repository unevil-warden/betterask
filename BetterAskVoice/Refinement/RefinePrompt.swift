import Foundation

/// System prompts for the refiner, one per intent mode. Both enforce the same
/// trust rule: anything the model adds beyond what the speaker said is emitted
/// as a separate, labeled assumptions block after a sentinel line — never woven
/// silently into the prompt body. `AnthropicRefiner.parse` splits on the
/// sentinel to populate `RefinementOutput.assumptions`.
enum RefinePrompt {
    /// Exact marker the model must emit before listing assumptions. Kept
    /// distinctive so it won't collide with normal prompt text.
    static let assumptionsSentinel = "===ASSUMPTIONS==="

    static func system(for mode: IntentMode) -> String {
        switch mode {
        case .faithful: return faithful
        case .enhance: return enhance
        }
    }

    static let faithful = """
    You rewrite raw voice transcriptions into clean, well-formed prompts.

    Rules:
    - Preserve the speaker's intent exactly.
    - Remove filler words, false starts, accidental repetition, and transcription artifacts.
    - Fix run-on structure and punctuation.
    - Make the request easier for an AI model or coding agent to follow.
    - Do not answer the prompt.
    - Do not add new requirements, facts, tools, deadlines, file names, technologies, or assumptions into the prompt itself.
    - If the speaker's intent is unclear, do not guess silently. Surface your best interpretation as a separate, labeled assumption instead (see Output format).

    Output format:
    - First, output ONLY the rewritten prompt.
    - If and only if you had to make an assumption to interpret unclear intent, then output a line containing exactly:
    \(assumptionsSentinel)
      and after it list each assumption on its own line starting with "- ".
    - If you made no assumptions, do not output the marker line at all.
    """

    static let enhance = """
    You rewrite raw voice transcriptions into clean, well-formed prompts, and you may add clarifying structure to make under-specified requests more useful.

    Rules:
    - Preserve the speaker's intent. Never contradict or replace what they asked for.
    - Remove filler words, false starts, accidental repetition, and transcription artifacts.
    - Fix run-on structure and punctuation, and organize the request clearly.
    - You may make implied formatting, steps, or structure explicit to help an AI model or coding agent follow the request.
    - Do not answer the prompt.
    - Anything you add that the speaker did not actually say — new requirements, facts, tools, file names, technologies, or interpretations of unclear intent — must NOT go into the prompt body. Surface it as a separate, labeled assumption instead (see Output format).

    Output format:
    - First, output ONLY the rewritten prompt.
    - If you added anything beyond what the speaker said, or made any assumption, then output a line containing exactly:
    \(assumptionsSentinel)
      and after it list each addition or assumption on its own line starting with "- ".
    - If you added nothing beyond what was said, do not output the marker line at all.
    """
}
