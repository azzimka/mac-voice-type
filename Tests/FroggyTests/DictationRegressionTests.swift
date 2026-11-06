import Foundation
import AppKit

final class DictationRegressionTests {
    func testSilencePeakAndReset() {
        for sampleRate in [16000.0, 44100.0, 48000.0] {
            let meter = RecordingSignalMeter()
            func feed(_ samples: [Float]) {
                samples.withUnsafeBufferPointer { meter.observe(samples: $0, sampleRate: sampleRate) }
            }
            let second = Int(sampleRate)
            feed([Float](repeating: 0, count: second))
            feed([Float](repeating: 0.0005, count: second))
            assert(!meter.hasSufficientSignal)
            // A single loud click in a long buffer must not qualify the recording.
            var click = [Float](repeating: 0, count: second)
            click[second / 2] = 1
            feed(click)
            assert(meter.peakAudioLevel >= RecordingSignalMeter.silenceThreshold)
            assert(!meter.hasSufficientSignal)
            meter.reset()
            assert(meter.peakAudioLevel == 0)
            feed([Float](repeating: 0.02, count: Int(sampleRate * 0.11)))
            assert(!meter.hasSufficientSignal)
            feed([Float](repeating: 0.02, count: Int(sampleRate * 0.01)))
            assert(meter.hasSufficientSignal)
            meter.reset()
            // Sustained signal qualifies even when split across irregular tap buffers.
            let signal = (0..<Int(sampleRate * 0.2)).map {
                Float(sin(2 * Double.pi * 220 * Double($0) / sampleRate)) * 0.02
            }
            for start in stride(from: 0, to: signal.count, by: 127) {
                feed(Array(signal[start..<min(start + 127, signal.count)]))
            }
            assert(meter.hasSufficientSignal)
            feed([Float](repeating: 0, count: second))
            assert(meter.hasSufficientSignal) // trailing silence preserves the utterance
            meter.reset()
            assert(!meter.hasSufficientSignal)
        }
    }

    func testArtifactsAndRealSpeech() {
        for text in ["", " \n", ".", " . ", "...", "…", "?!", "—", "。", "،", "git git git git", "Git, git, Git.",
                     "Субтитры создавал DimaTorzok", "DimaTorzok",
                     "Редактор субтитров Иван", "Продолжение следует...",
                     "да да да", "hello hello hello"] {
            assert(WhisperArtifactFilter.shouldDiscard(text), text)
        }
        for text in ["Да.", "No!", "42", "👍", "C++", "Git", "git git", "GitHub API macOS", "Привет, как дела?",
                     "Salom, ishlar yaxshimi?", "Нужно исправить git git git в тексте",
                     "Я сказал: продолжение следует завтра"] {
            assert(!WhisperArtifactFilter.shouldDiscard(text), text)
        }
    }

    @MainActor
    func testHUDResetsAndOldHideCannotCloseNewRecording() async throws {
        _ = NSApplication.shared
        let hud = FloatingHUDWindow.shared
        assert(FloatingHUDViewModel().state == .listening(level: 0, mode: .dictation))
        hud.update(state: .completed(message: "Готово!"))
        hud.hide()
        try await Task.sleep(for: .milliseconds(30))
        assert(!(hud.panel?.isVisible ?? true))
        assert(hud.viewModel.state == .listening(level: 0, mode: .dictation))

        for mode in [DictationMode.dictation, .translation] {
            hud.update(state: .completed(message: "Готово!"))
            hud.hide(delay: 0.05)
            hud.update(state: .listening(level: 0, mode: mode))
            try await Task.sleep(for: .milliseconds(100))
            assert(hud.panel?.isVisible ?? false)
            assert(hud.viewModel.state == .listening(level: 0, mode: mode))
        }
        hud.hide()
    }
}
