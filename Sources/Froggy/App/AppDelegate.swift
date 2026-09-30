import Cocoa
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Froggy] 🐸 App launched!")

        // Запуск координатора
        AppCoordinator.shared.start()

        // Проверка Accessibility (если нет — показывается системный диалог)
        let hasAccessibility = TextInjector.checkAccessibilityPermission(prompt: true)
        print("[Froggy] Accessibility: \(hasAccessibility)")

        // Запрос на микрофон
        Task {
            let hasMic = await AudioRecorder().requestPermission()
            print("[Froggy] Microphone permission: \(hasMic)")
        }

        // Если ключ ещё не введён — автоматически показываем окно настроек
        if KeychainHelper.getAPIKey() == nil || KeychainHelper.getAPIKey()?.isEmpty == true {
            print("[Froggy] No API key found, showing onboarding")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SettingsWindowController.shared.show()
            }
        } else {
            print("[Froggy] API key found, ready to use!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                FloatingHUDWindow.shared.update(state: .completed)
                FloatingHUDWindow.shared.hide(delay: 1.5)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }
}
