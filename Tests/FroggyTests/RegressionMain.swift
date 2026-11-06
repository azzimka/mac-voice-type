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
        print("PASS: silence/click/duration gate at 16/44.1/48 kHz, punctuation/artifact filter, HUD lifecycle (both modes), Whisper multipart without prompt")
    }
}
