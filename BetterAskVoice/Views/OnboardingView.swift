import SwiftUI
import AVFoundation
import Speech

struct OnboardingView: View {
    @EnvironmentObject private var settings: SettingsStore
    private let keychain = KeychainStore()
    @State private var anthropicKey = ""
    @State private var requesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                    Text("BetterAsk Voice")
                        .font(.largeTitle.bold())
                    Text("Speak a messy thought. Get a clean, well-formed prompt to paste into Claude, ChatGPT, or your coding agent.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    bullet("waveform", "Transcribed on-device by default", "Your audio stays on this iPhone. Audio is never saved.")
                    bullet("sparkles", "Refined, never invented", "Claude tidies what you said. Anything it guesses is shown separately — never silently added.")
                    bullet("lock", "Your keys, your data", "Your API key lives only in the Keychain. No backend, no tracking.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anthropic API key (optional)")
                        .font(.subheadline.weight(.semibold))
                    SecureField("sk-ant-…", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("Skip this and the app still works — it shows the raw transcript. You can add a key later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await getStarted() }
                } label: {
                    if requesting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Get Started").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(requesting)
            }
            .padding()
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func getStarted() async {
        requesting = true
        if !anthropicKey.isEmpty {
            keychain.set(anthropicKey, for: .anthropic)
        }
        // Prime permissions so the first recording is smooth. Declining is fine —
        // the user can grant later in Settings.
        _ = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        _ = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        requesting = false
        settings.hasCompletedOnboarding = true
    }
}
