import Cocoa
import Combine
import SwiftUI

/// Главный координатор приложения: связывает горячие клавиши, запись, ИИ и интерфейс
@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    @Published var isListening: Bool = false
    private let audioRecorder = AudioRecorder()
    private let hotkeyManager = HotkeyManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBindings()
    }

    func start() {
        hotkeyManager.startMonitoring()

        // Подписываемся на обновление звуковой волны во время записи
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self, self.isListening else { return }
                FloatingHUDWindow.shared.update(state: .listening(level: level))
            }
            .store(in: &cancellables)
    }

    private func setupBindings() {
        // Двойной тап Command -> Начать запись
        hotkeyManager.onDoubleTapCommand = { [weak self] in
            Task { @MainActor in
                self?.startDictation()
            }
        }

        // Повторный тап Command во время записи -> Остановить и вставить
        hotkeyManager.onSingleTapWhileRecording = { [weak self] in
            Task { @MainActor in
                self?.stopDictationAndProcess()
            }
        }
    }

    func startDictation() {
        guard !isListening else { return }

        // Проверяем наличие API-ключа
        guard let apiKey = KeychainHelper.getAPIKey(), !apiKey.isEmpty else {
            FloatingHUDWindow.shared.update(state: .error(message: "Укажите Groq API Key в настройках"))
            FloatingHUDWindow.shared.hide(delay: 2.5)
            openSettings()
            return
        }

        do {
            try audioRecorder.startRecording()
            isListening = true
            hotkeyManager.isRecordingActive = true
            FloatingHUDWindow.shared.update(state: .listening(level: 0))
        } catch {
            FloatingHUDWindow.shared.update(state: .error(message: error.localizedDescription))
            FloatingHUDWindow.shared.hide(delay: 2.0)
        }
    }

    func stopDictationAndProcess() {
        guard isListening else { return }
        isListening = false
        hotkeyManager.isRecordingActive = false

        guard let audioURL = audioRecorder.stopRecording() else {
            FloatingHUDWindow.shared.hide()
            return
        }

        FloatingHUDWindow.shared.update(state: .processing(stage: "Транскрибация речи..."))

        Task {
            guard let apiKey = KeychainHelper.getAPIKey() else { return }
            let whisperModel = UserDefaults.standard.string(forKey: "whisper_model") ?? "whisper-large-v3-turbo"
            let enableGrammar = UserDefaults.standard.object(forKey: "enable_grammar_correction") as? Bool ?? true

            do {
                // 1. Распознавание речи через Groq Whisper
                let rawText = try await GroqClient.shared.transcribeAudio(
                    fileURL: audioURL,
                    apiKey: apiKey,
                    model: whisperModel
                )

                // Сразу же удаляем временный аудиофайл
                audioRecorder.cleanup(fileURL: audioURL)

                guard !rawText.isEmpty else {
                    FloatingHUDWindow.shared.update(state: .error(message: "Речь не распознана"))
                    FloatingHUDWindow.shared.hide(delay: 1.5)
                    return
                }

                // 2. Исправление грамматики через Groq LLM (если включено)
                var finalText = rawText
                if enableGrammar {
                    FloatingHUDWindow.shared.update(state: .processing(stage: "Исправление грамматики..."))
                    finalText = try await GroqClient.shared.correctGrammar(text: rawText, apiKey: apiKey)
                }

                // 3. Вставка текста в активное поле ввода
                TextInjector.shared.insertText(finalText)

                // 4. Уведомление о завершении и скрытие
                FloatingHUDWindow.shared.update(state: .completed)
                FloatingHUDWindow.shared.hide(delay: 0.6)

            } catch {
                audioRecorder.cleanup(fileURL: audioURL)
                FloatingHUDWindow.shared.update(state: .error(message: error.localizedDescription))
                FloatingHUDWindow.shared.hide(delay: 2.5)
            }
        }
    }

    func openSettings() {
        SettingsWindowController.shared.show()
    }
}
