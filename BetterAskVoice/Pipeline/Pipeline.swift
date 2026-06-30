import Foundation

enum PipelineError: LocalizedError {
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "No speech was detected. Try recording again."
        }
    }
}

/// Orchestrates the voice → prompt flow and owns the safe-fallback ladder.
/// Direct port of the reference `voice_to_refined_prompt()` pseudocode:
/// the user is never blocked from using the raw transcript.
struct VoicePipeline {
    /// Optional so callers that orchestrate transcription themselves (e.g. to
    /// drive UI phases) can build a pipeline for the refinement ladder alone.
    let transcriber: Transcriber?
    /// Nil when refinement is unavailable (e.g. no API key). The pipeline then
    /// returns the raw transcript as the prompt rather than failing.
    let refiner: PromptRefiner?
    let config: AppConfig

    init(transcriber: Transcriber? = nil, refiner: PromptRefiner?, config: AppConfig) {
        self.transcriber = transcriber
        self.refiner = refiner
        self.config = config
    }

    /// Full run: transcribe, then refine.
    func run(audioURL: URL) async throws -> VoicePromptResult {
        guard let transcriber else {
            throw TranscriptionError.providerNotConfigured("No transcriber configured.")
        }
        let raw = try await transcriber.transcribe(audioURL: audioURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try await refine(rawTranscript: raw)
    }

    /// Refinement ladder, split out so it can be driven directly in tests with a
    /// known transcript (no audio/transcription needed).
    func refine(rawTranscript rawInput: String) async throws -> VoicePromptResult {
        let raw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { throw PipelineError.emptyTranscript }

        var warnings: [String] = []

        // No refiner, or the gate says it's already clean: use raw as the prompt.
        guard let refiner else {
            warnings.append("refinement_unavailable_used_raw_transcript")
            return result(raw: raw, refined: raw, assumptions: [], used: false, warnings: warnings)
        }
        guard RefineGate.shouldRefine(raw) else {
            warnings.append("refinement_skipped_clean_transcript")
            return result(raw: raw, refined: raw, assumptions: [], used: false, warnings: warnings)
        }

        do {
            let output = try await refiner.refine(transcript: raw, mode: config.intentMode)
            let refined = output.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if refined.isEmpty {
                warnings.append("refinement_returned_empty_used_raw_transcript")
                return result(raw: raw, refined: raw, assumptions: [], used: false, warnings: warnings)
            }
            return result(raw: raw, refined: refined, assumptions: output.assumptions, used: true, warnings: warnings)
        } catch {
            // Any failure (network, timeout, decode) falls back to the raw transcript.
            warnings.append("refinement_failed_used_raw_transcript")
            return result(raw: raw, refined: raw, assumptions: [], used: false, warnings: warnings)
        }
    }

    private func result(
        raw: String, refined: String, assumptions: [String], used: Bool, warnings: [String]
    ) -> VoicePromptResult {
        VoicePromptResult(
            rawTranscript: raw,
            refinedPrompt: refined,
            assumptions: assumptions,
            usedRefinement: used,
            intentMode: config.intentMode,
            transcriptionProvider: config.transcriptionProvider.rawValue,
            transcriptionModel: transcriptionModelLabel,
            refinementProvider: used ? config.refinementProvider.rawValue : nil,
            refinementModel: used ? config.refinementModel : nil,
            warnings: warnings,
            metadata: [:]
        )
    }

    private var transcriptionModelLabel: String {
        switch config.transcriptionProvider {
        case .onDevice: return "apple-speech"
        case .openAI: return config.transcriptionModel
        }
    }
}
