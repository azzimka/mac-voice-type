import Cocoa
import SwiftUI

@MainActor
final class FloatingHUDWindow: NSObject {
    static let shared = FloatingHUDWindow()
    private var panel: NSPanel?
    private let viewModel = FloatingHUDViewModel()
    private var hostingView: NSHostingView<FloatingHUDView>?

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
        panel.ignoresMouseEvents = true

        let contentView = FloatingHUDView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: contentView)
        self.hostingView = hosting
        panel.contentView = hosting

        self.panel = panel
    }

    func update(state: HUDState) {
        guard let panel = panel else { return }

        // Если это просто изменение уровня звука во время прослушивания —
        // мгновенно передаём уровень во ViewModel без тяжёлого пересчёта размера окна
        let isLevelUpdateOnly: Bool
        switch (viewModel.state, state) {
        case (.listening(_, let m1), .listening(_, let m2)):
            isLevelUpdateOnly = (m1 == m2)
        default:
            isLevelUpdateOnly = false
        }

        if isLevelUpdateOnly {
            viewModel.state = state
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                viewModel.state = state
            }

            if let hosting = hostingView {
                panel.layoutIfNeeded()
                let fittingSize = hosting.fittingSize
                if fittingSize.width > 50 && fittingSize.height > 20 {
                    panel.setContentSize(fittingSize)
                    if let screen = NSScreen.main {
                        let screenFrame = screen.visibleFrame
                        let x = screenFrame.midX - (fittingSize.width / 2.0)
                        let y = screenFrame.minY + 60.0
                        panel.setFrameOrigin(NSPoint(x: x, y: y))
                    }
                }
            }
        }

        if !panel.isVisible {
            panel.alphaValue = 0.0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 1.0
            }
        }
    }

    func hide(delay: TimeInterval = 0.0) {
        guard let panel = panel, panel.isVisible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let panel = self?.panel, panel.isVisible else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
}
