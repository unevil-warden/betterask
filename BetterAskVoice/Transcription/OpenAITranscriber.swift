import Foundation

/// Cloud transcription via the OpenAI audio API. Opt-in: choosing this provider
/// sends your audio to OpenAI (surfaced clearly in the UI). Mirrors the
/// reference `openai-audio-api` provider; model is configurable
/// (whisper-1 / gpt-4o-transcribe / gpt-4o-mini-transcribe).
struct OpenAITranscriber: Transcriber {
    let apiKey: String
    let model: String
    let timeout: TimeInterval
    let urlSession: URLSession

    private static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    init(apiKey: String, model: String, timeout: TimeInterval = 60, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.timeout = timeout
        self.urlSession = urlSession
    }

    func transcribe(audioURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary, audio: audioData, filename: audioURL.lastPathComponent)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TranscriptionError.providerNotConfigured(
                "OpenAI transcription failed (HTTP \(status)). Check your API key and model in Settings."
            )
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw TranscriptionError.emptyResult }
        return text
    }

    private func multipartBody(boundary: String, audio: Data, filename: String) -> Data {
        var body = Data()
        func appendString(_ string: String) { body.append(Data(string.utf8)) }

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        appendString("\(model)\r\n")

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: audio/m4a\r\n\r\n")
        body.append(audio)
        appendString("\r\n--\(boundary)--\r\n")
        return body
    }

    private struct OpenAIResponse: Decodable {
        let text: String
    }
}
