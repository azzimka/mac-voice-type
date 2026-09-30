import Cocoa
import Carbon

final class TextInjector {
    static let shared = TextInjector()
    private init() {}

    static func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func insertText(_ text: String) {
        guard !text.isEmpty else {
            print("[Froggy] TextInjector: text is empty, skipping")
            return
        }

        guard TextInjector.checkAccessibilityPermission(prompt: false) else {
            print("[Froggy] TextInjector: Accessibility permission NOT granted, cannot paste")
            return
        }

        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let savedChangeCount = pasteboard.changeCount
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

        // Set new text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is updated
        usleep(50_000) // 50ms

        // Simulate Cmd+V
        simulateCmdV()

        // Restore old clipboard after 500ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !savedItems.isEmpty {
                pasteboard.clearContents()
                pasteboard.writeObjects(savedItems)
            }
        }

        print("[Froggy] TextInjector: pasted \(text.count) chars")
    }

    private func simulateCmdV() {
        let vKeyCode: CGKeyCode = 0x09
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[Froggy] TextInjector: failed to create CGEvents")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
