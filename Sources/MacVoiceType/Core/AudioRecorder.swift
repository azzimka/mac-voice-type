import Foundation
import AVFoundation

/// Сервис захвата аудио с микрофона с замером уровня громкости для визуализации
@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0 // 0.0 ... 1.0 для плавной анимации волны

    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentAudioURL: URL?

    override init() {
        super.init()
    }

    /// Запрос прав на использование микрофона
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

    /// Запуск записи во временный файл
    func startRecording() throws {
        guard !isRecording else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_input_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.currentAudioURL = fileURL

        // Настройки формата AAC 16kHz mono (оптимально для Whisper, вес ~20 КБ/сек)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 32000
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw NSError(domain: "MacVoiceType", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось начать запись"])
        }

        self.audioRecorder = recorder
        self.isRecording = true

        // Таймер для обновления уровней громкости (30 fps)
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0) // децибелы от -160 до 0
                let minDb: Float = -60.0
                let clamped = max(minDb, min(0.0, power))
                let normalized = (clamped - minDb) / (0.0 - minDb)
                self.audioLevel = normalized
            }
        }
    }

    /// Остановка записи и возвращение URL аудиофайла
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        meterTimer?.invalidate()
        meterTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        audioLevel = 0.0

        return currentAudioURL
    }

    /// Отмена записи с немедленным удалением файла
    func cancelRecording() {
        let url = stopRecording()
        if let url = url {
            cleanup(fileURL: url)
        }
    }

    /// Удаление временного файла после отправки в Groq
    func cleanup(fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
