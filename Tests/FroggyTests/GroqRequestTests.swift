import Foundation

private final class WhisperStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        let multipart = String(decoding: body, as: UTF8.self)
        assert(request.url?.path == "/openai/v1/audio/transcriptions")
        assert(multipart.contains("whisper-large-v3-turbo"))
        assert(!multipart.contains("name=\"prompt\""))
        assert(multipart.contains("name=\"file\""))
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"text":"Привет, GitHub!"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class GroqRequestTests {
    func testWhisperRequestHasNoSyntheticPrompt() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WhisperStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try Data("test audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try await GroqClient(session: session).transcribeAudio(fileURL: url, apiKey: "test-key")
        assert(text == "Привет, GitHub!")
    }

    func testGeneratePythonVariableUsesGptOss120bAndSanitizesMarkdown() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PythonVariableStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let code = try await GroqClient(session: session).generatePythonVariable(text: "создай переменную user_age со значением 25", apiKey: "test-key")
        assert(code == "user_age = 25")
    }

    func testGeneratePythonDataStructureSanitizesMultilineCode() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PythonDictStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let code = try await GroqClient(session: session).generatePythonVariable(text: "создай словарь, словарь пользователей", apiKey: "test-key")
        assert(code.contains("users = {"))
        assert(code.contains("1: {\"first_name\": \"Иван\""))
    }
}

private final class PythonDictStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let mockCode = """
        ```python
        users = {
            1: {"first_name": "Иван", "last_name": "Иванов", "age": 30},
        }
        ```
        """
        let data = try! JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": mockCode]]]
        ])
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class PythonVariableStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        assert(request.url?.path == "/openai/v1/chat/completions")
        guard let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            assertionFailure("Failed to parse request JSON")
            return
        }
        assert(json["model"] as? String == "openai/gpt-oss-120b")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"choices":[{"message":{"content":"```python\nuser_age = 25\n```"}}]}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
