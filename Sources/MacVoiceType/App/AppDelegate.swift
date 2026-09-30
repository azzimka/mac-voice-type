import Cocoa
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Запускаем координатор и мониторинг глобальных клавиш
        AppCoordinator.shared.start()

        // Проверяем права на Универсальный доступ (Accessibility)
        _ = TextInjector.checkAccessibilityPermission(prompt: true)

        // Запрашиваем права на микрофон
        Task {
            if #available(macOS 14.0, *) {
                _ = await AVAudioApplication.requestRecordPermission()
            } else {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            }
        }

        // Если ключ еще не введен, сразу открываем окно настроек на экране!
        if KeychainHelper.getAPIKey() == nil || KeychainHelper.getAPIKey()?.isEmpty == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SettingsWindowController.shared.show()
            }
        } else {
            // Если ключ уже есть, показываем приветственную подсказку на долю секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                FloatingHUDWindow.shared.update(state: .completed)
                FloatingHUDWindow.shared.hide(delay: 1.5)
            }
        }
    }

    /// Когда пользователь кликает по приложению в Finder или Dock - открываем окно настроек
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }
}
