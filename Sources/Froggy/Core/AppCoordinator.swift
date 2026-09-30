import Cocoa
import Combine
import SwiftUI

/// Главный координатор: связывает горячие клавиши, запись, Groq API и HUD
@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    @Published var isListening: Bool = false
    private let audioRecorder = AudioRecorder()
    private let hotkeyManager = HotkeyManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: TimeInterval = 0
    private var currentMode: DictationMode = .dictation

    private init() {
        setupBindings()
    }

    func start() {
        print("[Froggy] AppCoordinator: starting...")
        hotkeyManager.startMonitoring()

        // Подписываемся на обновление звуковой волны
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self, self.isListening else { return }
                FloatingHUDWindow.shared.update(state: .listening(level: level, mode: self.currentMode))
            }
            .store(in: &cancellables)

        print("[Froggy] AppCoordinator: ready! 2x ⌘ for dictation, hold ⌘ (1s) for translator")
    }

    private func setupBindings() {
        // Режим 1: Двойной клик Command -> диктовка и исправление ошибок
        hotkeyManager.onDoubleTapCommand = { [weak self] in
            Task { @MainActor in
                self?.startDictation(mode: .dictation)
            }
        }

        hotkeyManager.onStopRecording = { [weak self] in
            Task { @MainActor in
                self?.stopDictationAndProcess()
            }
        }

        // Режим 2: Зажатие Command на 1 секунду -> живой переводчик (RU ⇄ EN)
        hotkeyManager.onHoldCommandStart = { [weak self] in
            Task { @MainActor in
                self?.startDictation(mode: .translation)
            }
        }

        hotkeyManager.onHoldCommandRelease = { [weak self] in
            Task { @MainActor in
                self?.stopDictationAndProcess()
            }
        }
    }

    func startDictation(mode: DictationMode) {
        guard !isListening else { return }

        guard let apiKey = KeychainHelper.getAPIKey(), !apiKey.isEmpty else {
            print("[Froggy] AppCoordinator: no API key!")
            FloatingHUDWindow.shared.update(state: .error(message: "Укажите Groq API Key"))
            FloatingHUDWindow.shared.hide(delay: 2.5)
            SettingsWindowController.shared.show()
            return
        }

        do {
            try audioRecorder.startRecording()
            self.currentMode = mode
            self.recordingStartTime = ProcessInfo.processInfo.systemUptime
            self.isListening = true
            self.hotkeyManager.isRecordingActive = true
            FloatingHUDWindow.shared.update(state: .listening(level: 0, mode: mode))
            print("[Froggy] AppCoordinator: recording STARTED (mode: \(mode))")
        } catch {
            print("[Froggy] AppCoordinator: failed to start recording: \(error)")
            FloatingHUDWindow.shared.update(state: .error(message: error.localizedDescription))
            FloatingHUDWindow.shared.hide(delay: 2.5)
        }
    }

    func stopDictationAndProcess() {
        guard isListening else { return }
        isListening = false
        hotkeyManager.isRecordingActive = false
        print("[Froggy] AppCoordinator: dictation STOPPED (mode: \(currentMode)), processing...")

        guard let audioURL = audioRecorder.stopRecording() else {
            FloatingHUDWindow.shared.hide()
            return
        }

        // Если запись длилась меньше 0.4 секунды — это случайное нажатие, закрываем тихо без ошибок
        let duration = ProcessInfo.processInfo.systemUptime - recordingStartTime
        if duration < 0.4 {
            print("[Froggy] AppCoordinator: recording too short (\(String(format: "%.2f", duration))s), cancelling quietly")
            FloatingHUDWindow.shared.hide(delay: 0.1)
            audioRecorder.cleanup(fileURL: audioURL)
            return
        }

        let stageText = currentMode == .translation ? "Перевожу..." : "Расшифровка речи..."
        FloatingHUDWindow.shared.update(state: .processing(stage: stageText, mode: currentMode))

        Task {
            guard let apiKey = KeychainHelper.getAPIKey() else { return }

            do {
                // 1. STT — Groq Whisper
                let rawText = try await GroqClient.shared.transcribeAudio(
                    fileURL: audioURL,
                    apiKey: apiKey
                )

                // Удаляем временный файл сразу
                audioRecorder.cleanup(fileURL: audioURL)

                guard !rawText.isEmpty else {
                    FloatingHUDWindow.shared.update(state: .error(message: "Речь не распознана"))
                    FloatingHUDWindow.shared.hide(delay: 1.5)
                    return
                }

                // 2. Обработка через Llama 3.3 в зависимости от режима:
                let finalText: String
                let successMessage: String

                if currentMode == .translation {
                    FloatingHUDWindow.shared.update(state: .processing(stage: "Перевожу RU ⇄ EN...", mode: .translation))
                    finalText = try await GroqClient.shared.translateText(text: rawText, apiKey: apiKey)
                    successMessage = "Переведено!"
                } else {
                    FloatingHUDWindow.shared.update(state: .processing(stage: "Исправление ошибок...", mode: .dictation))
                    finalText = try await GroqClient.shared.correctGrammar(text: rawText, apiKey: apiKey)
                    successMessage = "Готово!"
                }

                print("[Froggy] AppCoordinator: final text = \"\(finalText)\"")

                // 3. Вставка текста
                TextInjector.shared.insertText(finalText)

                // 4. Готово!
                FloatingHUDWindow.shared.update(state: .completed(message: successMessage))
                FloatingHUDWindow.shared.hide(delay: 0.8)

            } catch {
                print("[Froggy] AppCoordinator: error: \(error)")
                audioRecorder.cleanup(fileURL: audioURL)
                FloatingHUDWindow.shared.update(state: .error(message: error.localizedDescription))
                FloatingHUDWindow.shared.hide(delay: 2.5)
            }
        }
    }
}
