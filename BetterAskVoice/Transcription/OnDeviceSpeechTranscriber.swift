import Foundation
import Speech

/// On-device transcription using Apple's Speech framework. Forces
/// `requiresOnDeviceRecognition` so audio never leaves the phone — the
/// privacy-first default and the analog of the reference's local Whisper.
///
/// On iOS 26+, `SpeechAnalyzer`/`SpeechTranscriber` offer a newer long-form
/// engine; this implementation uses `SFSpeechRecognizer`, which is available
/// from iOS 17 and sufficient for short voice prompts. A future provider can
/// adopt `SpeechAnalyzer` behind the same `Transcriber` protocol.
struct OnDeviceSpeechTranscriber: Transcriber {
    let locale: Locale

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await Self.requestAuthorization()

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let text: String = try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !hasResumed { hasResumed = true; continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TranscriptionError.emptyResult }
        return trimmed
    }

    private static func requestAuthorization() async throws {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return }
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw TranscriptionError.permissionDenied }
    }
}
