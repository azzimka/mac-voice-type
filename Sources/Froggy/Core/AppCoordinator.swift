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

    private init() {
        setupBindings()
    }

    func start() {
        print("[Froggy] AppCoordinator: starting...")
        hotkeyManager.startMonitoring()

        // Подписываемся на обновление волны
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self, self.isListening else { return }
                FloatingHUDWindow.shared.update(state: .listening(level: level))
            }
            .store(in: &cancellables)

        print("[Froggy] AppCoordinator: ready! Double-tap ⌘ to start dictation")
    }

    private func setupBindings() {
        hotkeyManager.onDoubleTapCommand = { [weak self] in
            Task { @MainActor in
                self?.startDictation()
            }
        }

        hotkeyManager.onStopRecording = { [weak self] in
            Task { @MainActor in
                self?.stopDictationAndProcess()
            }
        }
    }

    func startDictation() {
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
            isListening = true
            hotkeyManager.isRecordingActive = true
            FloatingHUDWindow.shared.update(state: .listening(level: 0))
            print("[Froggy] AppCoordinator: dictation STARTED")
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
        print("[Froggy] AppCoordinator: dictation STOPPED, processing...")

        guard let audioURL = audioRecorder.stopRecording() else {
            FloatingHUDWindow.shared.hide()
            return
        }

        FloatingHUDWindow.shared.update(state: .processing(stage: "Расшифровка речи..."))

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

                // 2. Grammar fix — Groq LLM
                FloatingHUDWindow.shared.update(state: .processing(stage: "Исправление ошибок..."))
                let finalText = try await GroqClient.shared.correctGrammar(text: rawText, apiKey: apiKey)

                print("[Froggy] AppCoordinator: final text = \"\(finalText)\"")

                // 3. Вставка текста
                TextInjector.shared.insertText(finalText)

                // 4. Готово!
                FloatingHUDWindow.shared.update(state: .completed)
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
