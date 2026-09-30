import Foundation

enum GroqError: LocalizedError {
    case missingAPIKey
    case invalidResponse(statusCode: Int, message: String)
    case decodingError
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API ключ Groq не установлен"
        case .invalidResponse(let code, let msg):
            return "Groq API (\(code)): \(msg)"
        case .decodingError:
            return "Ошибка разбора ответа Groq"
        case .emptyTranscription:
            return "Речь не распознана"
        }
    }
}

final class GroqClient {
    static let shared = GroqClient()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func transcribeAudio(fileURL: URL, apiKey: String, model: String = "whisper-large-v3-turbo") async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GroqError.missingAPIKey }

        let audioData = try Data(contentsOf: fileURL)
        print("[Froggy] GroqClient: sending \(audioData.count) bytes to Whisper")
        guard !audioData.isEmpty else { throw GroqError.emptyTranscription }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("model", model)
        appendField("response_format", "json")
        appendField("temperature", "0.0")

        let filename = fileURL.lastPathComponent
        let mimeType = filename.hasSuffix(".wav") ? "audio/wav" : "audio/m4a"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse(statusCode: 0, message: "Bad response")
        }

        print("[Froggy] GroqClient: Whisper returned status \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Froggy] GroqClient: Whisper error: \(errorText)")
            throw GroqError.invalidResponse(statusCode: httpResponse.statusCode, message: errorText)
        }

        struct WhisperResponse: Codable { let text: String }
        let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Froggy] GroqClient: transcribed: \(text)")

        guard !text.isEmpty else { throw GroqError.emptyTranscription }
        return text
    }

    func correctGrammar(text: String, apiKey: String, model: String = "llama-3.3-70b-versatile") async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GroqError.missingAPIKey }

        if text.split(separator: " ").count <= 1 { return text }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are a strict grammar and punctuation corrector for Russian and English.
        RULES:
        1. Fix grammar, spelling, typos, and missing punctuation.
        2. Keep ALL original words, phrasing, slang, and word order.
        3. Do NOT paraphrase, rewrite, summarize, or add words.
        4. If text is already correct, return it unchanged.
        5. Output ONLY the corrected text. No quotes, no explanation.
        """

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[Froggy] GroqClient: grammar correction failed, returning raw text")
            return text
        }

        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        if let chatResp = try? JSONDecoder().decode(ChatResponse.self, from: data),
           let result = chatResp.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
           !result.isEmpty {
            print("[Froggy] GroqClient: corrected: \(result)")
            return result
        }

        return text
    }
}
