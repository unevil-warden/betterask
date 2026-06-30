import Foundation

/// Where transcription happens. Mirrors the swappable providers in the
/// reference pipeline (`local-whisper` / `openai-audio-api`), adapted to iOS:
/// on-device Apple Speech is the private default, OpenAI is the cloud option.
enum TranscriptionProvider: String, CaseIterable, Codable, Identifiable {
    case onDevice = "on-device"
    case openAI = "openai-audio-api"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onDevice: return "On-device (private)"
        case .openAI: return "OpenAI (cloud)"
        }
    }

    /// True when choosing this provider sends your audio off the phone.
    var sendsAudioOffDevice: Bool { self == .openAI }
}

enum RefinementProvider: String, Codable {
    case anthropic
}

/// How much latitude the refiner has. In both modes, anything the model adds
/// beyond what you said is surfaced separately as labeled assumptions — it is
/// never silently merged into the prompt body.
enum IntentMode: String, CaseIterable, Codable, Identifiable {
    case faithful
    case enhance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .faithful: return "Faithful"
        case .enhance: return "Enhance"
        }
    }

    var blurb: String {
        switch self {
        case .faithful:
            return "Clean up exactly what you said. Any guesses are listed separately, never woven in."
        case .enhance:
            return "Also add clarifying structure to vague prompts — additions are still listed separately."
        }
    }
}

/// Non-secret configuration consumed by the pipeline. Secrets (API keys) live
/// only in the Keychain, never here. Mirrors the reference `.env` block.
struct AppConfig: Codable {
    var transcriptionProvider: TranscriptionProvider = .onDevice
    /// Used only by the OpenAI provider. e.g. whisper-1 / gpt-4o-transcribe / gpt-4o-mini-transcribe.
    var transcriptionModel: String = "gpt-4o-mini-transcribe"
    var refinementProvider: RefinementProvider = .anthropic
    /// Configurable because model IDs change over time.
    var refinementModel: String = "claude-haiku-4-5-20251001"
    var intentMode: IntentMode = .faithful
    var storeTranscripts: Bool = false
    var refineTimeoutSeconds: Double = 8

    static let `default` = AppConfig()
}
