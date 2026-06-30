import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    private let keychain = KeychainStore()
    @State private var anthropicKey = ""
    @State private var openAIKey = ""
    @State private var savedTranscriptCount = 0

    var body: some View {
        NavigationStack {
            Form {
                transcriptionSection
                refinementSection
                intentSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                anthropicKey = keychain.get(.anthropic) ?? ""
                openAIKey = keychain.get(.openAI) ?? ""
                savedTranscriptCount = TranscriptLog().count
            }
        }
    }

    private var transcriptionSection: some View {
        Section {
            Picker("Provider", selection: $settings.transcriptionProvider) {
                ForEach(TranscriptionProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            if settings.transcriptionProvider.sendsAudioOffDevice {
                Label(
                    "Cloud transcription sends your audio to OpenAI.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                TextField("Model (e.g. gpt-4o-mini-transcribe)", text: $settings.transcriptionModel)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("OpenAI API key", text: $openAIKey)
                    .onSubmit { keychain.set(openAIKey, for: .openAI) }
                    .onChange(of: openAIKey) { _, new in keychain.set(new, for: .openAI) }
            }
        } header: {
            Text("Transcription")
        } footer: {
            Text("On-device keeps your audio on this iPhone. Cloud may be more accurate but sends audio to OpenAI.")
        }
    }

    private var refinementSection: some View {
        Section {
            SecureField("Anthropic API key", text: $anthropicKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { keychain.set(anthropicKey, for: .anthropic) }
                .onChange(of: anthropicKey) { _, new in keychain.set(new, for: .anthropic) }
            TextField("Refinement model", text: $settings.refinementModel)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                Label("How to get an Anthropic API key", systemImage: "key")
            }
        } header: {
            Text("Refinement (Claude)")
        } footer: {
            Text("Your key is stored only in the iOS Keychain. Without a key, the app still works — it shows the raw transcript.")
        }
    }

    private var intentSection: some View {
        Section {
            Picker("Default mode", selection: $settings.intentMode) {
                ForEach(IntentMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        } header: {
            Text("Intent")
        } footer: {
            Text(settings.intentMode.blurb + " Additions are always shown separately, never merged into the prompt.")
        }
    }

    private var privacySection: some View {
        Section {
            Toggle("Save transcripts on this device", isOn: $settings.storeTranscripts)
            if savedTranscriptCount > 0 {
                Button(role: .destructive) {
                    TranscriptLog().clear()
                    savedTranscriptCount = 0
                } label: {
                    Text("Delete \(savedTranscriptCount) saved transcript\(savedTranscriptCount == 1 ? "" : "s")")
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Audio is never saved. When off (the default), nothing you say is written to disk. When on, refined results are saved locally so you can review them — and never leave the device.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            Link(destination: URL(string: "https://github.com/unevil-warden/betterask")!) {
                Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        } header: {
            Text("About")
        } footer: {
            Text("BetterAsk Voice — speak a messy thought, get a clean prompt. The voice-native sibling of the BetterAsk browser extension.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
