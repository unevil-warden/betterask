import Foundation
import Combine

/// Observable, persisted wrapper around `AppConfig` for the UI. Non-secret
/// settings persist to `UserDefaults`; API keys are handled separately by
/// `KeychainStore`. Vends a plain `AppConfig` value for the pipeline.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var transcriptionProvider: TranscriptionProvider { didSet { persist() } }
    @Published var transcriptionModel: String { didSet { persist() } }
    @Published var refinementModel: String { didSet { persist() } }
    @Published var intentMode: IntentMode { didSet { persist() } }
    @Published var storeTranscripts: Bool { didSet { persist() } }
    @Published var hasCompletedOnboarding: Bool { didSet { persist() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = AppConfig.default
        self.transcriptionProvider = defaults.string(forKey: Keys.provider)
            .flatMap(TranscriptionProvider.init(rawValue:)) ?? fallback.transcriptionProvider
        self.transcriptionModel = defaults.string(forKey: Keys.model) ?? fallback.transcriptionModel
        self.refinementModel = defaults.string(forKey: Keys.refineModel) ?? fallback.refinementModel
        self.intentMode = defaults.string(forKey: Keys.intentMode)
            .flatMap(IntentMode.init(rawValue:)) ?? fallback.intentMode
        self.storeTranscripts = defaults.object(forKey: Keys.storeTranscripts) as? Bool ?? fallback.storeTranscripts
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
    }

    var config: AppConfig {
        AppConfig(
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            refinementProvider: .anthropic,
            refinementModel: refinementModel,
            intentMode: intentMode,
            storeTranscripts: storeTranscripts,
            refineTimeoutSeconds: AppConfig.default.refineTimeoutSeconds
        )
    }

    private func persist() {
        defaults.set(transcriptionProvider.rawValue, forKey: Keys.provider)
        defaults.set(transcriptionModel, forKey: Keys.model)
        defaults.set(refinementModel, forKey: Keys.refineModel)
        defaults.set(intentMode.rawValue, forKey: Keys.intentMode)
        defaults.set(storeTranscripts, forKey: Keys.storeTranscripts)
        defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded)
    }

    private enum Keys {
        static let provider = "transcriptionProvider"
        static let model = "transcriptionModel"
        static let refineModel = "refinementModel"
        static let intentMode = "intentMode"
        static let storeTranscripts = "storeTranscripts"
        static let onboarded = "hasCompletedOnboarding"
    }
}
