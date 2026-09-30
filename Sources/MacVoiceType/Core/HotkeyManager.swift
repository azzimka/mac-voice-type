import Cocoa

/// Менеджер отслеживания двойного нажатия клавиши Command во всей системе
@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    var onDoubleTapCommand: (() -> Void)?
    var onSingleTapWhileRecording: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var lastCommandPressTime: TimeInterval = 0
    private var isCommandDown: Bool = false
    private let doubleTapThreshold: TimeInterval = 0.35 // Максимальный интервал для двойного тапа (в секундах)

    var isRecordingActive: Bool = false

    private init() {}

    /// Запуск глобального мониторинга клавиш
    func startMonitoring() {
        stopMonitoring()

        // Отслеживаем изменения флагов (Command, Shift, Option и др.) глобально во всех приложениях
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleEvent(event)
            }
        }

        // Также отслеживаем локально (когда активно наше окно)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    /// Остановка мониторинга
    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        // Если была нажата обычная клавиша (например, 'c' при Cmd+C) - это шорткат, сбрасываем счетчик
        if event.type == .keyDown {
            lastCommandPressTime = 0
            return
        }

        guard event.type == .flagsChanged else { return }

        let isCmdNow = event.modifierFlags.contains(.command)

        // Ловим момент, когда клавиша Command именно НАЖАТА (переход из false в true)
        if isCmdNow && !isCommandDown {
            isCommandDown = true
            let currentTime = ProcessInfo.processInfo.systemUptime

            if isRecordingActive {
                // Если запись уже идет, любое повторное нажатие Command останавливает её
                onSingleTapWhileRecording?()
                lastCommandPressTime = 0
                return
            }

            let diff = currentTime - lastCommandPressTime

            // Если время между двумя нажатиями меньше порога — это Double-Tap!
            if diff > 0.05 && diff <= doubleTapThreshold {
                lastCommandPressTime = 0
                onDoubleTapCommand?()
            } else {
                lastCommandPressTime = currentTime
            }
        } else if !isCmdNow && isCommandDown {
            // Клавишу Command отпустили
            isCommandDown = false
        }
    }
}
