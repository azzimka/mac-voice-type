import SwiftUI

@main
struct FroggyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra("Froggy", systemImage: coordinator.isListening ? "waveform.circle.fill" : "mic.fill") {
            if coordinator.isListening {
                Button("🎙️ Остановить и вставить (⌘)") {
                    coordinator.stopDictationAndProcess()
                }
            } else {
                Button("🐸 Начать запись (2x ⌘)") {
                    coordinator.startDictation()
                }
            }

            Divider()

            Button("⚙️ Настройки...") {
                SettingsWindowController.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Завершить Froggy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
