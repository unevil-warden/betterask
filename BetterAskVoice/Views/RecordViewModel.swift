import Foundation

/// Drives the record screen: builds providers from settings + Keychain, runs the
/// pipeline, and publishes UI state. Holds the last transcript so the user can
/// re-refine (e.g. after switching Faithful/Enhance) without re-recording.
@MainActor
final class RecordViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case refining
        case done
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var result: VoicePromptResult?
    @Published var includeAssumptions = true

    let settings: SettingsStore
    private let recorder = AudioRecorder()
    private let keychain = KeychainStore()
    private var lastRawTranscript: String?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isRecording: Bool { phase == .recording }
    var isBusy: Bool { phase == .transcribing || phase == .refining }
    var canReRefine: Bool { lastRawTranscript != nil && !isBusy && !isRecording }

    // MARK: - Recording

    func toggleRecording() async {
        if recorder.isRecording {
            await finishAndProcess()
        } else {
            await beginRecording()
        }
    }

    private func beginRecording() async {
        result = nil
        guard await recorder.requestPermission() else {
            phase = .failed("Microphone access is needed to record. Enable it in Settings.")
            return
        }
        do {
            try recorder.start()
            phase = .recording
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func finishAndProcess() async {
        guard let audioURL = recorder.stop() else { phase = .idle; return }

        phase = .transcribing
        do {
            let transcriber = try makeTranscriber()
            let raw = try await transcriber.transcribe(audioURL: audioURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            recorder.discardRecording() // audio is never kept past transcription
            await runRefinement(raw: raw)
        } catch {
            recorder.discardRecording()
            phase = .failed(error.localizedDescription)
        }
    }

    /// Re-run refinement on the last transcript (e.g. after changing intent mode).
    func reRefine() async {
        guard let raw = lastRawTranscript else { return }
        await runRefinement(raw: raw)
    }

    private func runRefinement(raw: String) async {
        lastRawTranscript = raw
        let refiner = makeRefiner()
        if refiner != nil && RefineGate.shouldRefine(raw) {
            phase = .refining
        }
        let pipeline = VoicePipeline(refiner: refiner, config: settings.config)
        do {
            let result = try await pipeline.refine(rawTranscript: raw)
            self.result = result
            self.phase = .done
            if settings.storeTranscripts {
                TranscriptLog().append(result)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Provider construction

    private func makeTranscriber() throws -> Transcriber {
        switch settings.transcriptionProvider {
        case .onDevice:
            return OnDeviceSpeechTranscriber()
        case .openAI:
            guard let key = keychain.get(.openAI), !key.isEmpty else {
                throw TranscriptionError.providerNotConfigured(
                    "Add your OpenAI API key in Settings to use cloud transcription, or switch to on-device."
                )
            }
            return OpenAITranscriber(apiKey: key, model: settings.transcriptionModel)
        }
    }

    /// Returns nil when no Anthropic key is set — the pipeline then falls back to
    /// the raw transcript instead of failing.
    private func makeRefiner() -> PromptRefiner? {
        guard let key = keychain.get(.anthropic), !key.isEmpty else { return nil }
        return AnthropicRefiner(
            apiKey: key,
            model: settings.refinementModel,
            timeout: settings.config.refineTimeoutSeconds
        )
    }
}
