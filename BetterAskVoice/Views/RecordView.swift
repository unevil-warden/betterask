import SwiftUI
import UIKit

struct RecordView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var vm: RecordViewModel
    @State private var showSettings = false
    /// Local, editable copy of the refiner's assumptions so the user can delete
    /// any they disagree with before copying.
    @State private var assumptions: [String] = []
    @State private var copied = false

    init(settings: SettingsStore) {
        _vm = StateObject(wrappedValue: RecordViewModel(settings: settings))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    intentPicker
                    recordButton
                    statusLine
                    if let result = vm.result {
                        resultSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("BetterAsk Voice")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }
            .onChange(of: vm.result?.id) { _, _ in
                assumptions = vm.result?.assumptions ?? []
                copied = false
            }
        }
    }

    // MARK: - Controls

    private var intentPicker: some View {
        VStack(spacing: 6) {
            Picker("Mode", selection: $settings.intentMode) {
                ForEach(IntentMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(settings.intentMode.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var recordButton: some View {
        Button {
            Task { await vm.toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(vm.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 120, height: 120)
                    .shadow(radius: vm.isRecording ? 12 : 4)
                Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(vm.isBusy)
        .accessibilityLabel(vm.isRecording ? "Stop recording" : "Start recording")
    }

    @ViewBuilder
    private var statusLine: some View {
        switch vm.phase {
        case .idle:
            Text("Tap to record a messy thought.")
                .foregroundStyle(.secondary)
        case .recording:
            Label("Recording… tap to stop", systemImage: "waveform")
                .foregroundStyle(.red)
        case .transcribing:
            ProgressView("Transcribing…")
        case .refining:
            ProgressView("Refining…")
        case .done:
            EmptyView()
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private func resultSection(_ result: VoicePromptResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            refinedCard(result)

            if !assumptions.isEmpty {
                assumptionsCard
            }

            rawCard(result)

            if !result.warnings.isEmpty {
                Text(result.warnings.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func refinedCard(_ result: VoicePromptResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(result.usedRefinement ? "Refined prompt" : "Transcript")
                    .font(.headline)
                Spacer()
                if !result.usedRefinement {
                    Text("raw")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
            }
            Text(result.refinedPrompt)
                .textSelection(.enabled)

            HStack {
                Button {
                    UIPasteboard.general.string = composedPrompt(result)
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: composedPrompt(result)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Spacer()

                if vm.canReRefine {
                    Button {
                        Task { await vm.reRefine() }
                    } label: {
                        Label("Refine again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var assumptionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Assumptions", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Include when copying", isOn: $vm.includeAssumptions)
                    .labelsHidden()
            }
            Text("The model guessed these. Delete any that are wrong; toggle whether they're included when you copy.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(assumptions.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 7)
                    Text(item).font(.callout)
                    Spacer()
                    Button {
                        assumptions.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove assumption")
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.35), lineWidth: 1)
        )
    }

    private func rawCard(_ result: VoicePromptResult) -> some View {
        DisclosureGroup("What you said (raw transcript)") {
            Text(result.rawTranscript)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .font(.subheadline)
    }

    private func composedPrompt(_ result: VoicePromptResult) -> String {
        var out = result.refinedPrompt
        if vm.includeAssumptions && !assumptions.isEmpty {
            let block = assumptions.map { "- \($0)" }.joined(separator: "\n")
            out += "\n\nAssumptions (delete if wrong):\n\(block)"
        }
        return out
    }
}
