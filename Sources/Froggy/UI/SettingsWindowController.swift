import Cocoa
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private init() {}

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.title = "Froggy"
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.contentView = NSHostingView(rootView: OnboardingView())
            win.isReleasedWhenClosed = false
            win.backgroundColor = .clear
            self.window = win
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
