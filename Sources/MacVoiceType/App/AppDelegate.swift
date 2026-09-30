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
    }
}
