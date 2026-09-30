import Foundation
import AVFoundation

/// Надёжный сервис записи голоса с микрофона через AVAudioEngine (не AVAudioRecorder!)
/// AVAudioEngine даёт прямой доступ к аудиопотоку и точный замер громкости.
@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var currentFileURL: URL?
    private var smoothedLevel: Float = 0.0

    private func updateSmoothedLevel(_ rawLevel: Float) {
        // Мгновенный отклик на голос (0.88) и упругое органичное затухание (0.35)
        let factor: Float = rawLevel > smoothedLevel ? 0.88 : 0.35
        smoothedLevel = smoothedLevel * (1.0 - factor) + rawLevel * factor
        audioLevel = smoothedLevel
    }

    /// Запрос разрешения на микрофон
    func requestPermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Запуск записи через AVAudioEngine
    func startRecording() throws {
        guard !isRecording else {
            print("[Froggy] AudioRecorder: already recording")
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Получаем нативный формат микрофона
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        print("[Froggy] AudioRecorder: mic format = \(nativeFormat)")

        guard nativeFormat.sampleRate > 0, nativeFormat.channelCount > 0 else {
            throw NSError(domain: "Froggy", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Микрофон недоступен. Проверьте разрешения в Системных настройках."
            ])
        }

        // Целевой формат для Whisper: 16kHz mono PCM (WAV)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "Froggy", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось создать аудио формат"
            ])
        }

        // Создаём временный файл
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "froggy_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.currentFileURL = fileURL

        let file = try AVAudioFile(forWriting: fileURL, settings: targetFormat.settings)
        self.audioFile = file

        // Конвертер из нативного формата микрофона в 16kHz mono
        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            throw NSError(domain: "Froggy", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось создать аудио конвертер"
            ])
        }

        // Устанавливаем tap на микрофон
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            // Замер уровня громкости (RMS)
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let data = channelData, frameLength > 0 {
                var sumOfSquares: Float = 0
                for i in 0..<frameLength {
                    sumOfSquares += data[i] * data[i]
                }
                let rms = sqrtf(sumOfSquares / Float(frameLength))
                // Сверхвысокая чувствительность к живой речи:
                // Откликается даже на спокойную речь и тихие согласные звуки
                let effectiveRMS = max(0.0, rms - 0.001)
                let normalizedLevel = min(1.0, powf(effectiveRMS * 22.0, 0.60))
                DispatchQueue.main.async {
                    self?.updateSmoothedLevel(normalizedLevel)
                }
            }

            // Конвертируем и записываем в файл
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * targetFormat.sampleRate / nativeFormat.sampleRate
            )
            guard frameCapacity > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
                return
            }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, convertedBuffer.frameLength > 0 {
                do {
                    try file.write(from: convertedBuffer)
                } catch {
                    print("[Froggy] AudioRecorder: write error: \(error)")
                }
            }
        }

        // Запуск движка
        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.isRecording = true
        print("[Froggy] AudioRecorder: recording started -> \(fileURL.lastPathComponent)")
    }

    /// Остановка записи и возврат URL аудиофайла
    func stopRecording() -> URL? {
        guard isRecording, let engine = audioEngine else {
            print("[Froggy] AudioRecorder: not recording")
            return nil
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.audioEngine = nil
        self.audioFile = nil
        self.isRecording = false
        self.audioLevel = 0.0
        self.smoothedLevel = 0.0

        if let url = currentFileURL {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("[Froggy] AudioRecorder: stopped. File size: \(fileSize) bytes")
            if fileSize < 1000 {
                print("[Froggy] AudioRecorder: WARNING - file is very small, speech might not be detected")
            }
        }

        return currentFileURL
    }

    /// Удаление временного файла
    func cleanup(fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
        print("[Froggy] AudioRecorder: cleaned up \(fileURL.lastPathComponent)")
    }
}
