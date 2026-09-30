import Cocoa
import SwiftUI

/// Контроллер плавающего окна (HUD), парящего над всеми приложениями
@MainActor
final class FloatingHUDWindow: NSObject {
    static let shared = FloatingHUDWindow()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    private override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // Не перехватывает клики мыши

        self.panel = panel
    }

    /// Отобразить HUD с определенным состоянием
    func update(state: HUDState) {
        guard let panel = panel else { return }

        let contentView = FloatingHUDView(state: state)
        let hosting = NSHostingView(rootView: AnyView(contentView))
        panel.contentView = hosting
        panel.layoutIfNeeded()

        // Вычисляем оптимальный размер под контент
        let fittingSize = hosting.fittingSize
        panel.setContentSize(fittingSize)

        // Позиционируем окно: по центру внизу экрана
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - (fittingSize.width / 2.0)
            let y = screenFrame.minY + 60.0 // 60px от нижнего края экрана / Dock

            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        if !panel.isVisible {
            panel.alphaValue = 0.0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 1.0
            }
        }
    }

    /// Плавно скрыть HUD
    func hide(delay: TimeInterval = 0.0) {
        guard let panel = panel, panel.isVisible else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let panel = self?.panel, panel.isVisible else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
}
