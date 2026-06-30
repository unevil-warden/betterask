import Foundation

/// Cheap, local "is this worth a model call?" gate. Direct port of the
/// reference `should_refine()`. It only decides whether refinement is worth the
/// cost/latency — it never modifies text.
enum RefineGate {
    static let fillerTerms = [
        "um", "uh", "like", "you know", "i mean", "kind of", "sort of",
        "basically", "actually", "okay so",
    ]

    static func shouldRefine(_ text: String) -> Bool {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty { return false }

        let words = stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let lower = stripped.lowercased()

        // Substring counts, matching the reference implementation's str.count().
        let fillerHits = fillerTerms.reduce(0) { $0 + lower.occurrences(of: $1) }
        let hasRunOn = words.count > 35 && !stripped.contains(".")
        let hasRepetition = (1..<words.count).contains {
            words[$0].lowercased() == words[$0 - 1].lowercased()
        }

        return words.count > 12 && (fillerHits >= 2 || hasRunOn || hasRepetition)
    }
}

private extension String {
    /// Non-overlapping occurrences of `needle`, matching Python's str.count().
    func occurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var range = startIndex..<endIndex
        while let found = self.range(of: needle, range: range) {
            count += 1
            range = found.upperBound..<endIndex
        }
        return count
    }
}
