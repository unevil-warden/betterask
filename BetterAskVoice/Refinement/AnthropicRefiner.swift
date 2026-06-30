import Foundation

/// Refines a transcript via the Anthropic Messages REST API. No SDK dependency —
/// a plain URLSession call keeps the app dependency-free.
struct AnthropicRefiner: PromptRefiner {
    let apiKey: String
    let model: String
    let maxTokens: Int
    let timeout: TimeInterval
    let urlSession: URLSession

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    init(
        apiKey: String,
        model: String,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 8,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.timeout = timeout
        self.urlSession = urlSession
    }

    func refine(transcript: String, mode: IntentMode) async throws -> RefinementOutput {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload = RequestBody(
            model: model,
            max_tokens: maxTokens,
            system: RefinePrompt.system(for: mode),
            messages: [.init(role: "user", content: transcript)]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RefinerError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw RefinerError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        return Self.parse(text)
    }

    /// Split the model's reply on the assumptions sentinel. If the marker is
    /// absent, the whole reply is the prompt and there are no assumptions.
    static func parse(_ raw: String) -> RefinementOutput {
        let parts = raw.components(separatedBy: RefinePrompt.assumptionsSentinel)
        let prompt = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard parts.count > 1 else { return RefinementOutput(prompt: prompt, assumptions: []) }

        let assumptions = parts[1]
            .split(whereSeparator: \.isNewline)
            .map { line -> String in
                var trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- ") { trimmed.removeFirst(2) }
                else if trimmed.hasPrefix("-") { trimmed.removeFirst() }
                return trimmed.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
        return RefinementOutput(prompt: prompt, assumptions: assumptions)
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ResponseBody: Decodable {
        let content: [Block]
        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }
}

enum RefinerError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The refinement service returned an unexpected response."
        case .http(let status, _):
            switch status {
            case 401: return "Your Anthropic API key was rejected (401). Check it in Settings."
            case 429: return "Rate limited by Anthropic (429). Try again in a moment."
            default: return "Refinement failed (HTTP \(status))."
            }
        }
    }
}
