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

        // Set new text directly to pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is updated
        usleep(50_000) // 50ms

        // Simulate Cmd+V
        simulateCmdV()

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
