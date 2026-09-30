import SwiftUI

@main
struct MacVoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra("Mac Voice Type", systemImage: coordinator.isListening ? "waveform.circle.fill" : "mic.fill") {
            Button(coordinator.isListening ? "Остановить запись (⌘)" : "Начать запись (2x ⌘)") {
                if coordinator.isListening {
                    coordinator.stopDictationAndProcess()
                } else {
                    coordinator.startDictation()
                }
            }

            Divider()

            Button("Настройки...") {
                SettingsWindowController.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Завершить Mac Voice Type") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
