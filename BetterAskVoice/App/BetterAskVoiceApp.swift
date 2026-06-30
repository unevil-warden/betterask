import SwiftUI

@main
struct BetterAskVoiceApp: App {
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
        }
    }
}

/// Shows onboarding until it's completed, then the main record screen.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        if settings.hasCompletedOnboarding {
            RecordView(settings: settings)
        } else {
            OnboardingView()
        }
    }
}
