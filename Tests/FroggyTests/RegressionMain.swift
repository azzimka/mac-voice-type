import Foundation

@main
struct RegressionMain {
    @MainActor
    static func main() async throws {
        let tests = DictationRegressionTests()
        tests.testSilencePeakAndReset()
        tests.testArtifactsAndRealSpeech()
        try await tests.testHUDResetsAndOldHideCannotCloseNewRecording()
        try await GroqRequestTests().testWhisperRequestHasNoSyntheticPrompt()
        try await GroqRequestTests().testGeneratePythonVariableUsesGptOss120bAndSanitizesMarkdown()
        print("PASS: silence/click/duration gate, punctuation/artifact filter, HUD lifecycle (3 modes: dictation, translator, dev), Whisper multipart without prompt, Python variable via gpt-oss-120b")
    }
}
