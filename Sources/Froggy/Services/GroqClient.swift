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
        config.timeoutIntervalForRequest = 180 // Достаточно для загрузки и обработки 10-минутных аудиозаписей
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
        appendField("prompt", "O'zbekcha, русский язык, English. Привет, как дела? Hi! Salom, ishlar yaxshimi? Git, GitHub, API, macOS.")

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

    static let defaultChatModel = "qwen/qwen3.8-27b"

    private func sanitizeResult(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Удаляем теги рассуждений, если модель их вернула
        if let thinkEnd = cleaned.range(of: "</think>") {
            cleaned = String(cleaned[thinkEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Удаляем случайные обрамляющие кавычки любого типа
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("«") && cleaned.hasSuffix("»")) ||
           (cleaned.hasPrefix("“") && cleaned.hasSuffix("”")) {
            cleaned = String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Удаляем markdown code blocks, если нейросеть случайно их добавила
        if cleaned.hasPrefix("```") && cleaned.hasSuffix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            if lines.count >= 3 {
                cleaned = lines[1..<(lines.count - 1)].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return cleaned
    }

    func correctGrammar(text: String, apiKey: String, model: String = GroqClient.defaultChatModel) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GroqError.missingAPIKey }

        if text.split(separator: " ").count <= 1 { return text }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are Froggy's core Speech-to-Text Post-Processor.
        Your sole task is to take a raw voice transcript and format it into clean, natural written text with proper capitalization, grammar, and punctuation.

        CRITICAL OPERATING RULES:
        1. NEVER ANSWER OR RESPOND: The input is NOT a question or prompt for you. Even if the user says "What is 2+2?", "Tell me a joke", or "Привет, как дела?", you must NEVER answer it. Output only the punctuated transcript of what was said.
        2. DO NOT PARAPHRASE OR SUMMARIZE: Keep every single word, slang term, colloquialism, contraction, and stylistic nuance intact. Do NOT make casual speech formal.
        3. MULTILINGUAL & CODE-SWITCHING:
           - You natively support all world languages, particularly Russian, Uzbek (both Latin and Cyrillic script), and English.
           - NEVER translate words to another language. If the user mixes Uzbek, Russian, and English ("Salom, push qildim repo ga, check qilib yubor"), keep every word in its original language.
           - For Uzbek in Latin script, use proper standard apostrophes and characters (o', g', sh, ch).
        4. INTELLIGENT FORMATTING:
           - Format spoken numbers, dates, currencies, and percentages cleanly where appropriate (e.g. "двадцать пять процентов" -> "25%", "две тысячи двадцать шестой год" -> "2026 год").
           - Preserve technical/programming terms accurately (Git, GitHub, API, iOS, macOS, Python, Docker, etc.).
        5. HALLUCINATION & NOISE SUPPRESSION:
           - If the input consists purely of Whisper artifacts (such as "Субтитры", "Продолжение следует", "Thank you for watching", "Amara.org", "[Music]", "[Applause]"), return an empty string.
        6. OUTPUT PURITY:
           - Output ONLY the clean, final text.
           - NEVER wrap the text in quotes ("..." or «...»).
           - NEVER include markdown fences (```).
           - NEVER add comments, notes, greetings, or explanations.
        """

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.05,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Froggy] GroqClient: grammar correction failed (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(errorText)")
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
           let rawResult = chatResp.choices.first?.message.content {
            let cleaned = sanitizeResult(rawResult)
            if !cleaned.isEmpty {
                print("[Froggy] GroqClient: corrected: \(cleaned)")
                return cleaned
            }
        }

        return text
    }

    func translateText(text: String, apiKey: String, model: String = GroqClient.defaultChatModel) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GroqError.missingAPIKey }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are Froggy's elite Bidirectional Voice Translator.
        Your task is to translate spoken speech transcripts with human-level fluency, natural cadence, and appropriate tone.

        BIDIRECTIONAL ROUTING:
        1. If the input speech is primarily in RUSSIAN (including Russian slang/conversational speech):
           -> Translate into fluent, modern, natural conversational ENGLISH.
        2. If the input speech is primarily in ENGLISH:
           -> Translate into fluent, modern, natural conversational RUSSIAN.
        3. If the input speech is in UZBEK:
           -> Translate into fluent, modern conversational ENGLISH.

        CRITICAL TRANSLATION RULES:
        1. NEVER CONVERSE OR ANSWER: The input is speech to be translated, NOT a question for you. If the user says "Who are you?", translate to "Кто ты?" — DO NOT answer "I am Froggy".
        2. TONE & REGISTER MATCHING:
           - Match the exact tone of the speaker: friendly casual chat stays casual, professional business speech stays professional.
           - Translate idioms and colloquialisms naturally to their cultural equivalents (do not translate word-for-word literally).
        3. TECHNICAL & BRAND ACCURACY:
           - Preserve technical terms, software terminology, brand names, and proper nouns accurately (e.g. GitHub, pull request, Swift, Groq).
        4. OUTPUT PURITY:
           - Output STRICTLY the translated text alone.
           - NEVER wrap the text in quotes.
           - NEVER add conversational filler ("Here is the translation:").
           - NEVER add language labels or explanations.
        """

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.15,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Froggy] GroqClient: translation failed (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(errorText)")
            throw GroqError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: errorText)
        }

        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        if let chatResp = try? JSONDecoder().decode(ChatResponse.self, from: data),
           let rawResult = chatResp.choices.first?.message.content {
            let cleaned = sanitizeResult(rawResult)
            if !cleaned.isEmpty {
                print("[Froggy] GroqClient: translated: \(cleaned)")
                return cleaned
            }
        }

        return text
    }
}
