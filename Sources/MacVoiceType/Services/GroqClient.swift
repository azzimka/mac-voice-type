import Foundation

/// Ошибки работы с Groq API
enum GroqError: LocalizedError {
    case missingAPIKey
    case invalidResponse(statusCode: Int, message: String)
    case decodingError
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Не указан Groq API Key. Пожалуйста, сохраните ключ в настройках."
        case .invalidResponse(let code, let msg):
            return "Ошибка Groq API (\(code)): \(msg)"
        case .decodingError:
            return "Не удалось разобрать ответ от сервера Groq."
        case .emptyAudio:
            return "Аудиозапись пустая или не содержит данных."
        }
    }
}

/// Сервис взаимодействия с нейросетевым API Groq (Whisper + Llama)
final class GroqClient {
    static let shared = GroqClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Транскрибация аудиофайла через модель Whisper на Groq LPU
    func transcribeAudio(fileURL: URL, apiKey: String, model: String = "whisper-large-v3-turbo") async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.missingAPIKey
        }

        let audioData = try Data(contentsOf: fileURL)
        guard !audioData.isEmpty else {
            throw GroqError.emptyAudio
        }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Поле model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Поле response_format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        // Поле temperature
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        body.append("0.0\r\n".data(using: .utf8)!)

        // Аудио файл
        let filename = fileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Финальный boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse(statusCode: 0, message: "Некорректный сетевой ответ")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка"
            throw GroqError.invalidResponse(statusCode: httpResponse.statusCode, message: errorText)
        }

        struct WhisperResponse: Codable {
            let text: String
        }

        do {
            let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw GroqError.decodingError
        }
    }

    /// Коррекция грамматики и пунктуации через сверхбыструю LLM без изменения авторского стиля
    func correctGrammar(text: String, apiKey: String, model: String = "llama-3.3-70b-versatile") async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroqError.missingAPIKey
        }

        // Если текст слишком короткий (1-2 слова), нет смысла прогонять через LLM
        let words = text.split(separator: " ")
        if words.count <= 1 {
            return text
        }

        let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are a strict grammar, orthography, and punctuation corrector for Russian and English.
        TASK:
        Correct grammatical errors, spelling mistakes, typos, and missing punctuation in the transcribed speech.
        
        CRITICAL RULES:
        1. Keep ALL original words, phrasing, slang, and word order intact.
        2. DO NOT paraphrase, rewrite, summarize, explain, or complete thoughts.
        3. DO NOT change the tone or author's voice.
        4. If the text is already correct, return it unchanged.
        5. Output ONLY the resulting corrected text. Do NOT wrap in quotes, do NOT add greetings or intro words.
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse(statusCode: 0, message: "Некорректный сетевой ответ")
        }

        guard httpResponse.statusCode == 200 else {
            // Если LLM вернула ошибку, не ломаем весь процесс, а просто возвращаем сырой текст Whisper
            return text
        }

        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        if let chatResp = try? JSONDecoder().decode(ChatResponse.self, from: data),
           let result = chatResp.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
           !result.isEmpty {
            return result
        }

        return text
    }
}
