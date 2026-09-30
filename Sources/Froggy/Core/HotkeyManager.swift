import Cocoa

/// Менеджер горячих клавиш:
/// 1. Двойной тап Command -> диктовка (на том же языке с исправлением)
/// 2. Зажатие Command на 1.0 сек -> живой переводчик (RU ⇄ EN)
@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    var onDoubleTapCommand: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onHoldCommandStart: (() -> Void)?
    var onHoldCommandRelease: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastCommandUpTime: TimeInterval = 0
    private var isCommandDown: Bool = false
    private let doubleTapThreshold: TimeInterval = 0.4
    private let holdThreshold: TimeInterval = 1.0
    private var otherKeyPressedDuringCommand: Bool = false
    private var holdWorkItem: DispatchWorkItem?

    var isRecordingActive: Bool = false
    var isHoldRecordingActive: Bool = false

    private init() {}

    func startMonitoring() {
        stopMonitoring()
        print("[Froggy] HotkeyManager: starting global key monitoring")

        let hasAccess = TextInjector.checkAccessibilityPermission(prompt: false)
        print("[Froggy] HotkeyManager: Accessibility permission = \(hasAccess)")

        if !hasAccess {
            print("[Froggy] HotkeyManager: Accessibility not yet granted, monitoring will activate once granted")
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    func stopMonitoring() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    private func handleEvent(_ event: NSEvent) {
        // Если во время удержания Command нажали другую клавишу — это системный шорткат (Cmd+C, Cmd+Tab и т.д.)
        if event.type == .keyDown {
            if isCommandDown {
                otherKeyPressedDuringCommand = true
                holdWorkItem?.cancel()
                holdWorkItem = nil
            }
            return
        }

        guard event.type == .flagsChanged else { return }

        let isCmdNow = event.modifierFlags.contains(.command)

        if isCmdNow && !isCommandDown {
            // Command НАЖАТ
            isCommandDown = true
            otherKeyPressedDuringCommand = false

            // Если обычная диктовка уже идёт — одиночное нажатие Command останавливает её
            if isRecordingActive {
                print("[Froggy] HotkeyManager: Cmd pressed during recording -> stopping")
                onStopRecording?()
                lastCommandUpTime = 0
                return
            }

            // Запускаем таймер на 1.0 секунду для режима Переводчика
            holdWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isCommandDown && !self.otherKeyPressedDuringCommand && !self.isRecordingActive {
                    print("[Froggy] HotkeyManager: HOLD COMMAND (1s) triggered -> TRANSLATOR MODE")
                    self.isHoldRecordingActive = true
                    self.onHoldCommandStart?()
                }
            }
            self.holdWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)

        } else if !isCmdNow && isCommandDown {
            // Command ОТПУЩЕН
            isCommandDown = false

            // Отменяем таймер удержания
            holdWorkItem?.cancel()
            holdWorkItem = nil

            // Если это был режим переводчика (зажатие 1 сек), то при отпускании завершаем запись и переводим!
            if isHoldRecordingActive {
                print("[Froggy] HotkeyManager: Command RELEASED -> stopping translator recording")
                isHoldRecordingActive = false
                lastCommandUpTime = 0
                onHoldCommandRelease?()
                return
            }

            // Если во время Command нажимали другую клавишу — это шорткат, игнорируем
            if otherKeyPressedDuringCommand {
                lastCommandUpTime = 0
                return
            }

            // Проверяем двойной тап по моменту ОТПУСКАНИЯ для обычной диктовки
            let now = ProcessInfo.processInfo.systemUptime

            if !isRecordingActive {
                let diff = now - lastCommandUpTime
                if diff > 0.05 && diff <= doubleTapThreshold {
                    print("[Froggy] HotkeyManager: DOUBLE TAP detected! (diff=\(String(format: "%.3f", diff))s)")
                    lastCommandUpTime = 0
                    onDoubleTapCommand?()
                } else {
                    lastCommandUpTime = now
                }
            }
        }
    }
}
