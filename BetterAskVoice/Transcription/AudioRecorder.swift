import Foundation
import AVFoundation

/// Records microphone audio to a temporary AAC (.m4a) file. The file is the
/// hand-off point both transcription providers consume. By default the file is
/// deleted after transcription (`discardRecording`) so no audio is retained.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    /// Prompts for microphone permission (iOS 17+ API).
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.record()

        self.recorder = recorder
        self.currentURL = url
        self.isRecording = true
    }

    /// Stops recording and returns the file URL of the captured audio.
    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return currentURL
    }

    /// Deletes the temporary recording. Call after transcription so audio isn't
    /// kept on disk.
    func discardRecording() {
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentURL = nil
    }
}
