import Foundation

enum GroqError: LocalizedError {
    case missingAPIKey
    case invalidResponse(statusCode: Int, message: String)
    case decodingError
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Укажите Groq API ключ"
        case .invalidResponse(_, let rawMsg):
            return GroqClient.formatErrorMessage(rawMsg)
        case .decodingError:
            return "Ошибка обработки ответа"
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

    static func formatErrorMessage(_ raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any] {
            if let code = errorObj["code"] as? String {
                switch code {
                case "audio_too_short":
                    return "Слишком короткая запись"
                case "invalid_api_key":
                    return "Неверный Groq API ключ"
                case "rate_limit_exceeded":
                    return "Превышен лимит запросов к Groq"
                default:
                    break
                }
            }
            if let msg = errorObj["message"] as? String {
                if msg.contains("too short") {
                    return "Слишком короткая запись"
                }
                return msg
            }
        }

        if raw.contains("audio_too_short") || raw.contains("too short") {
            return "Слишком короткая запись"
        }
        if raw.contains("invalid_api_key") {
            return "Неверный Groq API ключ"
        }

        return "Ошибка распознавания речи"
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
        appendField("prompt", "O'zbekcha, русский, English, multi-language speech, IT terms, code-switching.")

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
        You are an expert multilingual grammar, spelling, and punctuation corrector.
        You natively support all world languages, especially Uzbek (O'zbek tili in Latin and Cyrillic script), Russian, and English, including natural mixed multilingual speech (code-switching).

        CRITICAL RULES:
        1. Fix only obvious typos, spelling mistakes, and missing punctuation (periods, commas, question marks).
        2. NEVER translate words into another language. Every word must stay in its original spoken language.
        3. If the user mixes Uzbek, Russian, and English in one sentence, KEEP all words in their respective languages.
        4. Preserve all original slang, conversational phrasing, technical terms (e.g. Git, push, branch, deploy, link), and exact word order.
        5. For Uzbek words in Latin script, preserve proper apostrophes and letters (o', g', sh, ch).
        6. Do NOT rewrite, summarize, explain, or paraphrase.
        7. Output ONLY the clean corrected text. No quotes, no markdown fences, no comments.
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

    func translateText(text: String, apiKey: String, model: String = "llama-3.3-70b-versatile") async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GroqError.missingAPIKey }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are an elite bilingual speech translator between Russian and English.
        Analyze the input speech transcript and determine its language:
        1. If primarily in Russian (or Russian slang/speech):
           -> Translate accurately, fluently, and naturally into modern conversational ENGLISH.
        2. If primarily in English:
           -> Translate accurately, fluently, and naturally into modern conversational RUSSIAN.
        3. If in Uzbek:
           -> Translate accurately into modern ENGLISH.

        STRICT TRANSLATION RULES:
        - Output ONLY the final translated text.
        - NEVER add quotes, notes, comments, or explanations.
        - Preserve natural phrasing, colloquial idioms, and technical terms.
        """

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.2,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[Froggy] GroqClient: translation failed, falling back to raw text")
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
            print("[Froggy] GroqClient: translated: \(result)")
            return result
        }

        return text
    }
}
