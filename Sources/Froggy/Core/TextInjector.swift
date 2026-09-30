import Cocoa
import Carbon

/// Надежный сервис прямого ввода распознанного текста в активное приложение.
///
/// Преимущества:
/// 1. Прямой ввод через CoreGraphics Unicode Key Events (postToPid / cghidEventTap).
/// 2. Буфер обмена пользователя (NSPasteboard.general) НЕ ЗАТРАГИВАЕТСЯ:
///    - Скопированные пользователем данные сохраняются в первозданном виде.
///    - Сторонние приложения (Reverso, Alfred, Raycast) не получают ложных событий
///      изменения буфера и не всплывают на экране.
/// 3. Пакетная передача (до 20 Unicode символов в одном событии) обеспечивает
///    мгновенную вставку текста любой длины без задержек.
final class TextInjector {
    static let shared = TextInjector()
    private init() {}

    static func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func insertText(_ text: String, targetApp: NSRunningApplication? = nil) {
        guard !text.isEmpty else {
            print("[Froggy] TextInjector: text is empty, skipping")
            return
        }

        DispatchQueue.main.async { [self] in
            self.performDirectInsert(text, targetApp: targetApp)
        }
    }

    private func performDirectInsert(_ text: String, targetApp: NSRunningApplication?) {
        // Определяем целевое приложение (переданное или текущее активное)
        let app = (targetApp != nil && !(targetApp?.isTerminated ?? true))
            ? targetApp
            : NSWorkspace.shared.frontmostApplication

        guard let target = app else {
            print("[Froggy] TextInjector: no target application, fallback to HID event tap")
            typeViaHID(text)
            return
        }

        // Если фокус временно сместился, мягко возвращаем фокус целевому приложению
        if target.processIdentifier != NSWorkspace.shared.frontmostApplication?.processIdentifier {
            if #available(macOS 14.0, *) {
                target.activate()
            } else {
                target.activate(options: [.activateIgnoringOtherApps])
            }
            usleep(25_000) // 25 мс для активации окна
        }

        let pid = target.processIdentifier
        let source = CGEventSource(stateID: .combinedSessionState)
        let chars = Array(text)
        let chunkSize = 20

        print("[Froggy] TextInjector: directly typing \(chars.count) chars into \(target.localizedName ?? "app") (PID: \(pid)) without touching clipboard")

        for i in stride(from: 0, to: chars.count, by: chunkSize) {
            let end = min(i + chunkSize, chars.count)
            let chunkString = String(chars[i..<end])
            var utf16 = Array(chunkString.utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }

            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

            keyDown.postToPid(pid)
            keyUp.postToPid(pid)
            usleep(1500) // 1.5 мс между пакетами для надежной обработки полем ввода
        }

        print("[Froggy] TextInjector: direct insertion completed successfully")
    }

    private func typeViaHID(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let chars = Array(text)
        let chunkSize = 20

        for i in stride(from: 0, to: chars.count, by: chunkSize) {
            let end = min(i + chunkSize, chars.count)
            let chunkString = String(chars[i..<end])
            var utf16 = Array(chunkString.utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }

            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            usleep(1500)
        }
    }
}
