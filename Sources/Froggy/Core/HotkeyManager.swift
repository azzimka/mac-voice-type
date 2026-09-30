import Cocoa

/// Менеджер горячих клавиш: отслеживание двойного нажатия Command
@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    var onDoubleTapCommand: (() -> Void)?
    var onStopRecording: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastCommandUpTime: TimeInterval = 0
    private var isCommandDown: Bool = false
    private let doubleTapThreshold: TimeInterval = 0.4
    private var otherKeyPressedDuringCommand: Bool = false

    var isRecordingActive: Bool = false

    private init() {}

    func startMonitoring() {
        stopMonitoring()
        print("[Froggy] HotkeyManager: starting global key monitoring")

        // Проверяем Accessibility
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
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    private func handleEvent(_ event: NSEvent) {
        // Если нажали обычную клавишу во время удержания Command — это шорткат (Cmd+C и т.д.)
        if event.type == .keyDown {
            if isCommandDown {
                otherKeyPressedDuringCommand = true
            }
            return
        }

        guard event.type == .flagsChanged else { return }

        let isCmdNow = event.modifierFlags.contains(.command)

        if isCmdNow && !isCommandDown {
            // Command НАЖАТ
            isCommandDown = true
            otherKeyPressedDuringCommand = false

            // Если запись уже идёт — одиночное нажатие Command останавливает её
            if isRecordingActive {
                print("[Froggy] HotkeyManager: Cmd pressed during recording -> stopping")
                onStopRecording?()
                lastCommandUpTime = 0
                return
            }
        } else if !isCmdNow && isCommandDown {
            // Command ОТПУЩЕН
            isCommandDown = false

            // Если во время удержания Command нажимали другую клавишу — это шорткат, игнорируем
            if otherKeyPressedDuringCommand {
                lastCommandUpTime = 0
                return
            }

            // Проверяем двойной тап по моменту ОТПУСКАНИЯ
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
