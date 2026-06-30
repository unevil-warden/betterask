import Foundation

/// Opt-in, on-device history of results. Nothing is written unless the user
/// turns on "Save transcripts" in Settings. Stored as a plain JSON file in
/// Application Support; never leaves the device.
struct TranscriptLog {
    private let fileURL: URL

    init(filename: String = "betterask-transcripts.json") {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)
    }

    func append(_ result: VoicePromptResult) {
        var all = load()
        all.append(result)
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func load() -> [VoicePromptResult] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([VoicePromptResult].self, from: data)) ?? []
    }

    var count: Int { load().count }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
