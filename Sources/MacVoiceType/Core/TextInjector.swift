import Cocoa
import Carbon

/// Менеджер умной вставки текста в активное поле ввода без потери старого буфера обмена
final class TextInjector {
    static let shared = TextInjector()

    private init() {}

    /// Проверка наличия прав Accessibility (Универсальный доступ)
    static func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Вставка текста в текущее активное приложение
    func insertText(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // 1. Сохраняем текущие элементы буфера обмена пользователя
        var savedItems: [NSPasteboardItem] = []
        if let currentItems = pasteboard.pasteboardItems {
            for item in currentItems {
                let copyItem = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        copyItem.setData(data, forType: type)
                    }
                }
                savedItems.append(copyItem)
            }
        }

        // 2. Помещаем новый распознанный текст в буфер
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Эмулируем нажатие Cmd + V
        simulateCmdV()

        // 4. Спустя 400 мс восстанавливаем старый буфер обмена
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard !savedItems.isEmpty else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(savedItems)
        }
    }

    /// Программная эмуляция комбинации клавиш ⌘ + V через CoreGraphics
    private func simulateCmdV() {
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

        let source = CGEventSource(stateID: .combinedSessionState)

        // Нажатие клавиши V с флагом Command
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand

        // Отпускание клавиши V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        // Отправка событий в систему
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
