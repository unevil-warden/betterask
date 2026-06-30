import Foundation

/// Swappable transcription provider. Implementations turn a recorded audio file
/// into raw text. Kept deliberately minimal so providers (on-device, cloud, or
/// a future one) are interchangeable without touching the pipeline.
protocol Transcriber {
    func transcribe(audioURL: URL) async throws -> String
}

enum TranscriptionError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case emptyResult
    case providerNotConfigured(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission was denied. Enable it in Settings to transcribe."
        case .recognizerUnavailable:
            return "On-device speech recognition isn't available for this language on this device."
        case .emptyResult:
            return "No speech was detected in the recording."
        case .providerNotConfigured(let why):
            return why
        }
    }
}
